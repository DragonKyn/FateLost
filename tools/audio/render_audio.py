#!/usr/bin/env python3
"""Renders Fate Lost's music, ambience and sound effects.

Every sound in the game is synthesised here from first principles (oscillators,
plucked-string models, FM bells, filtered noise, convolution reverb). Nothing is
sampled or downloaded, so the audio is wholly original to Fate Lost and free of
third-party licences.

The score is built around one leitmotif, "Fate", in D minor: a rising fifth
that falls back by step (D - A - G F - E). It opens the main theme, drives the
Ashen Wilds battle theme at double tempo on horns and choir, and closes the
defeat sting on a lone music box, so the game has one recognisable melody.

Output is deterministic: the same script always renders the same files.

    python3 tools/audio/render_audio.py            # everything
    python3 tools/audio/render_audio.py --only sfx # just effects
    python3 tools/audio/render_audio.py --out DIR

Only numpy is required. CI renders the audio before building and converts the
music to AAC; locally the WAV files can be auditioned directly.
"""

import argparse
import os
import sys
import time
import wave

import numpy as np

SR = 44100
TAU = 2 * np.pi


# ---------------------------------------------------------------------------
# Basics
# ---------------------------------------------------------------------------

def secs(seconds):
    return max(0, int(round(seconds * SR)))


NOTE_OFFSETS = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6,
                "Gb": 6, "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}


def midi(name):
    """'D4' -> 62. Octave is the last character."""
    return 12 * (int(name[-1]) + 1) + NOTE_OFFSETS[name[:-1]]


def hz(note):
    m = midi(note) if isinstance(note, str) else note
    return 440.0 * 2 ** ((m - 69) / 12)


def fit(signal, length):
    if len(signal) >= length:
        return signal[:length]
    return np.concatenate([signal, np.zeros(length - len(signal))])


def envelope(duration, attack=0.01, decay=0.1, sustain=0.7, release=0.3):
    """Note-on for `duration` seconds, then an exponential release."""
    n_on = max(1, secs(duration))
    n_attack = max(1, secs(attack))
    n_decay = max(1, secs(decay))
    n_release = max(1, secs(release))
    t = np.arange(n_on, dtype=float)
    e = np.empty(n_on)
    rising = t < n_attack
    # Slightly curved attack reads as natural rather than switched on.
    e[rising] = np.sin(0.5 * np.pi * t[rising] / n_attack)
    held = ~rising
    e[held] = sustain + (1 - sustain) * np.exp(-(t[held] - n_attack) / (n_decay / 3))
    tail = e[-1] * np.exp(-np.arange(n_release) / (n_release / 5.5))
    return np.concatenate([e, tail])


def pan_gains(pan):
    """Equal-power pan, -1 left .. 1 right."""
    angle = (pan + 1) * np.pi / 4
    return np.cos(angle), np.sin(angle)


def saw(phase, dt):
    """Band-limited sawtooth (polyBLEP). `phase` in cycles, `dt` cycles/sample."""
    t = np.mod(phase, 1.0)
    y = 2 * t - 1
    dt = np.broadcast_to(np.asarray(dt, dtype=float), t.shape)
    low = t < dt
    x = t[low] / dt[low]
    y[low] -= x + x - x * x - 1
    high = t > 1 - dt
    x = (t[high] - 1) / dt[high]
    y[high] -= x * x + x + x + 1
    return y


def vibrato_frequency(f, n, rate, depth, delay, rng):
    t = np.arange(n) / SR
    onset = np.clip((t - delay) / 0.5, 0, 1)
    wobble = np.sin(TAU * rate * t + rng.uniform(0, TAU))
    # A little slow drift so sustained notes breathe.
    drift = 0.0012 * np.sin(TAU * 0.23 * t + rng.uniform(0, TAU))
    return f * (1 + depth * onset * wobble + drift)


# ---------------------------------------------------------------------------
# Filters (offline, zero-phase, FFT based)
# ---------------------------------------------------------------------------

def next_pow2(n):
    return 1 << (int(n) - 1).bit_length()


def spectral(x, gain_fn, circular=False):
    """Applies a frequency-domain gain curve. `circular` keeps the length exact
    so looped material stays seamless."""
    n = x.shape[-1]
    nfft = n if circular else next_pow2(n + SR // 2)
    spectrum = np.fft.rfft(x, nfft)
    spectrum *= gain_fn(np.fft.rfftfreq(nfft, 1 / SR))
    return np.fft.irfft(spectrum, nfft)[..., :n]


def lowpass(cutoff, order=2):
    return lambda f: 1 / np.sqrt(1 + (f / cutoff) ** (2 * order))


def highpass(cutoff, order=2):
    return lambda f: 1 / np.sqrt(1 + (cutoff / np.maximum(f, 1e-3)) ** (2 * order))


def bandpass(center, width_octaves=1.0):
    def gain(f):
        octaves = np.log2(np.maximum(f, 1) / center)
        return np.exp(-0.5 * (octaves / (width_octaves / 2.355 * 2)) ** 2)
    return gain


def peaks(bands, floor=0.0):
    """Sum of resonances [(centre Hz, gain, width in octaves)] over a floor."""
    def gain(f):
        g = np.full_like(f, floor, dtype=float)
        for center, amount, width in bands:
            octaves = np.log2(np.maximum(f, 1) / center)
            g += amount * np.exp(-0.5 * (octaves / (width / 2.355)) ** 2)
        return g
    return gain


def chain(*gains):
    def gain(f):
        g = np.ones_like(f, dtype=float)
        for fn in gains:
            g = g * fn(f)
        return g
    return gain


# ---------------------------------------------------------------------------
# Reverb
# ---------------------------------------------------------------------------

def impulse_response(rt60, predelay, damping, seed, width=1.0):
    """Stereo hall: early reflections, then a diffuse tail whose highs die
    faster than its lows."""
    rng = np.random.default_rng(seed)
    n = secs(rt60 * 1.1)
    t = np.arange(n) / SR
    tau = rt60 / 6.9
    ir = np.zeros((2, n))
    for ch in range(2):
        bright = rng.standard_normal(n) * np.exp(-t / (tau * 0.35))
        dark = spectral(rng.standard_normal(n), lowpass(damping, 1)) * np.exp(-t / tau)
        tail = 0.45 * bright + dark
        # Soft onset of the diffuse field.
        tail *= np.clip(t / 0.06, 0, 1)
        for _ in range(9):
            tap = secs(rng.uniform(0.007, 0.055))
            tail[tap] += rng.uniform(-1.2, 1.2)
        ir[ch] = tail
    mid = ir.mean(axis=0)
    ir = mid + (ir - mid) * width
    ir /= np.sqrt(np.sum(ir ** 2) / 2)
    return np.concatenate([np.zeros((2, secs(predelay))), ir], axis=1)


def convolve(stereo, ir):
    n = stereo.shape[1] + ir.shape[1]
    nfft = next_pow2(n)
    out = np.empty((2, n - 1))
    for ch in range(2):
        spectrum = np.fft.rfft(stereo[ch], nfft) * np.fft.rfft(ir[ch], nfft)
        out[ch] = np.fft.irfft(spectrum, nfft)[: n - 1]
    return out


# ---------------------------------------------------------------------------
# Instruments. Each returns a mono signal including its release tail.
# ---------------------------------------------------------------------------

def strings(f, duration, velocity, rng, attack=0.35, release=0.7, voices=3, detune=7.0, vibrato=0.0035):
    tail = release
    n = secs(duration + tail)
    out = np.zeros(n)
    for v in range(voices):
        cents = (v - (voices - 1) / 2) * (2 * detune / max(voices - 1, 1))
        freq = vibrato_frequency(f * 2 ** (cents / 1200), n, 5.1 + 0.4 * v, vibrato, 0.25, rng)
        out += saw(np.cumsum(freq) / SR + rng.uniform(), freq / SR)
    out /= voices
    return out * fit(envelope(duration, attack, 0.4, 0.85, release), n) * velocity


def choir(f, duration, velocity, rng, attack=0.5, release=0.9):
    n = secs(duration + release)
    out = np.zeros(n)
    for v in range(4):
        cents = rng.uniform(-11, 11)
        freq = vibrato_frequency(f * 2 ** (cents / 1200), n, 5.3 + rng.uniform(-0.4, 0.4), 0.006, 0.3, rng)
        out += saw(np.cumsum(freq) / SR + rng.uniform(), freq / SR)
    out /= 4
    # Breath: a whisper of noise under the voices.
    out += 0.05 * rng.standard_normal(n)
    return out * fit(envelope(duration, attack, 0.5, 0.9, release), n) * velocity


def solo_cello(f, duration, velocity, rng, attack=0.12, release=0.45):
    n = secs(duration + release)
    freq = vibrato_frequency(f, n, 5.2, 0.0065, 0.28, rng)
    phase = np.cumsum(freq) / SR
    out = 0.7 * saw(phase, freq / SR) + 0.3 * saw(phase * 1.0017 + 0.3, freq * 1.0017 / SR)
    # Bow pressure swells a little into each note.
    swell = fit(envelope(duration, attack, 0.6, 0.8, release), n)
    swell *= 1 + 0.12 * np.sin(np.pi * np.clip(np.arange(n) / max(secs(duration), 1), 0, 1))
    return out * swell * velocity


def horn(f, duration, velocity, rng, attack=0.07, release=0.3):
    n = secs(duration + release)
    amp = fit(envelope(duration, attack, 0.25, 0.8, release), n)
    brightness = (0.25 + 0.75 * amp) * (0.55 + 0.45 * velocity)
    freq = vibrato_frequency(f, n, 4.9, 0.003, 0.3, rng)
    phase = TAU * np.cumsum(freq) / SR
    harmonics = max(1, min(18, int(9000 / f)))
    out = np.zeros(n)
    for k in range(1, harmonics + 1):
        weight = (1 / k) * np.exp(-(k - 1) / (0.8 + 6.5 * brightness))
        out += np.sin(k * phase) * weight
    return out * amp * velocity * 0.9


def low_strings(f, duration, velocity, rng):
    n = secs(duration + 0.12)
    out = np.zeros(n)
    for cents in (-6, 5):
        freq = f * 2 ** (cents / 1200)
        out += saw(freq * np.arange(n) / SR + rng.uniform(), freq / SR)
    return out * 0.5 * fit(envelope(duration, 0.006, 0.09, 0.35, 0.1), n) * velocity


def karplus(f, seconds, rng, brightness=0.7, t60=2.0):
    """Plucked string. Rendered with an integer delay line, then resampled so
    the pitch is exact."""
    period = SR / f
    delay = max(2, int(np.floor(period - 0.5)))
    rate = (delay + 0.5) / period
    total = secs(seconds)
    length = int(total * rate) + delay + 4
    excitation = rng.uniform(-1, 1, delay)
    smooth = max(1, int(round((1 - brightness) * 6)) + 1)
    if smooth > 1:
        excitation = np.convolve(excitation, np.ones(smooth) / smooth, mode="same")
    excitation -= excitation.mean()
    rho = 10 ** (-3 / (t60 * f))
    out = np.zeros(length)
    out[:delay] = excitation
    pos = delay
    while pos < length:
        end = min(pos + delay, length)
        span = end - pos
        a = out[pos - delay: pos - delay + span]
        start = pos - delay - 1
        b = out[start: start + span] if start >= 0 else np.concatenate([[0.0], out[: span - 1]])
        out[pos:end] = rho * 0.5 * (a + b)
        pos = end
    return np.interp(np.arange(total) * rate, np.arange(length), out)


def harp(f, duration, velocity, rng):
    t60 = float(np.clip(3.2 - f / 500, 1.3, 3.0))
    tone = karplus(f, t60 * 0.9, rng, brightness=0.55, t60=t60)
    body = spectral(tone, peaks([(f, 0.4, 0.6), (f * 2, 0.2, 0.6)], floor=1.0))
    return body * velocity


def bell(f, duration, velocity, rng, decay=2.4, ratio=3.0, index=1.5):
    n = secs(decay * 1.4)
    t = np.arange(n) / SR
    mod_index = index * np.exp(-t / 0.3)
    carrier = np.sin(TAU * f * t + mod_index * np.sin(TAU * f * ratio * t))
    glint = 0.25 * np.sin(TAU * f * 2.756 * t) * np.exp(-t / (decay * 0.25))
    amp = np.exp(-t / (decay / 3)) * np.clip(t / 0.002, 0, 1)
    return (carrier + glint) * amp * velocity


def gong(f, seconds, velocity, rng):
    n = secs(seconds)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for ratio, level, decay in [(1, 1, 6), (1.52, 0.6, 5), (2.03, 0.45, 4.2), (2.64, 0.35, 3.4),
                                (3.4, 0.25, 2.6), (4.13, 0.18, 2), (5.2, 0.12, 1.4)]:
        detune = 1 + rng.uniform(-0.002, 0.002)
        out += level * np.sin(TAU * f * ratio * detune * t + rng.uniform(0, TAU)) * np.exp(-t / (decay / 2))
    swell = np.clip(t / 0.04, 0, 1)
    return out * swell * velocity * 0.4


def taiko(velocity, rng, pitch=64.0, length=1.3):
    n = secs(length)
    t = np.arange(n) / SR
    freq = pitch * (1 + 1.1 * np.exp(-t / 0.028))
    body = np.sin(TAU * np.cumsum(freq) / SR) * np.exp(-t / 0.32)
    skin = spectral(rng.standard_normal(n), chain(lowpass(1400, 2), highpass(90))) * np.exp(-t / 0.018)
    sub = np.sin(TAU * pitch * 0.72 * t) * np.exp(-t / 0.45)
    return (body + 0.55 * skin + 0.45 * sub) * velocity


def frame_drum(velocity, rng):
    n = secs(0.35)
    t = np.arange(n) / SR
    noise = spectral(rng.standard_normal(n), bandpass(2200, 2.2)) * np.exp(-t / 0.05)
    tone = np.sin(TAU * 185 * t) * np.exp(-t / 0.045)
    return (noise * 1.3 + tone * 0.6) * velocity


def tom(velocity, rng, pitch=120.0):
    n = secs(0.7)
    t = np.arange(n) / SR
    freq = pitch * (1 + 0.5 * np.exp(-t / 0.04))
    body = np.sin(TAU * np.cumsum(freq) / SR) * np.exp(-t / 0.2)
    skin = spectral(rng.standard_normal(n), lowpass(2500, 2)) * np.exp(-t / 0.015)
    return (body + 0.35 * skin) * velocity


def shaker(velocity, rng):
    n = secs(0.09)
    t = np.arange(n) / SR
    noise = spectral(rng.standard_normal(n), chain(highpass(4500, 2), lowpass(11000, 1)))
    return noise * np.clip(t / 0.006, 0, 1) * np.exp(-t / 0.028) * velocity


def cymbal_swell(seconds, velocity, rng):
    n = secs(seconds + 0.25)
    t = np.arange(n) / SR
    noise = spectral(rng.standard_normal(n), chain(highpass(3000, 2), lowpass(12000, 1)))
    rise = (np.clip(t / seconds, 0, 1) ** 3) * (t <= seconds) + (t > seconds) * np.exp(-(t - seconds) / 0.05)
    return noise * rise * velocity


def drone(f, seconds, velocity, rng):
    """A sustained tone that repeats exactly every `seconds`: every partial
    and the slow swell complete whole cycles, so it loops without a seam."""
    n = secs(seconds)
    period = n / SR
    t = np.arange(n) / SR

    def whole(frequency):
        return max(1, round(frequency * period)) / period

    out = (np.sin(TAU * whole(f) * t) + 0.35 * np.sin(TAU * whole(2 * f) * t + 0.4)
           + 0.15 * np.sin(TAU * whole(3.01 * f) * t))
    out *= 1 + 0.12 * np.sin(TAU * whole(0.11) * t + rng.uniform(0, TAU))
    return out * velocity


# ---------------------------------------------------------------------------
# Arrangement helpers
# ---------------------------------------------------------------------------

class Track:
    """Named stereo stems on a shared timeline, mixed at the end."""

    def __init__(self, seconds, tail, seed):
        self.length = secs(seconds)
        self.total = secs(seconds + tail)
        self.stems = {}
        self.rng = np.random.default_rng(seed)

    def stem(self, name):
        if name not in self.stems:
            self.stems[name] = np.zeros((2, self.total))
        return self.stems[name]

    def add(self, name, signal, start, pan=0.0, gain=1.0):
        target = self.stem(name)
        begin = secs(start)
        if begin >= self.total:
            return
        end = min(self.total, begin + len(signal))
        left, right = pan_gains(pan)
        target[0, begin:end] += signal[: end - begin] * left * gain
        target[1, begin:end] += signal[: end - begin] * right * gain

    def add_wide(self, name, make, start, width=0.6, gain=1.0):
        """Renders a part twice with independent randomness and spreads the
        copies left and right, for a wide section sound."""
        self.add(name, make(), start, -width, gain * 0.75)
        self.add(name, make(), start, width, gain * 0.75)


def active_rms_db(stereo):
    mono = stereo.mean(axis=0)
    window = secs(0.05)
    usable = len(mono) // window * window
    if usable == 0:
        return -120.0
    blocks = np.sqrt(np.mean(mono[:usable].reshape(-1, window) ** 2, axis=1))
    loud = np.sort(blocks)[-max(1, len(blocks) * 3 // 10):]
    value = float(np.mean(loud))
    return 20 * np.log10(max(value, 1e-9))


def normalize_to(stereo, target_db):
    level = active_rms_db(stereo)
    if level < -100:
        return stereo
    return stereo * 10 ** ((target_db - level) / 20)


def compress(stereo, threshold_db=-18.0, ratio=2.2, smoothing=0.08):
    """Gentle bus compressor with a smoothed, zero-phase level detector."""
    level = np.sqrt(spectral(np.mean(stereo ** 2, axis=0), lowpass(1 / smoothing, 1)).clip(1e-12))
    level_db = 20 * np.log10(level)
    over = np.maximum(level_db - threshold_db, 0)
    gain = 10 ** (-over * (1 - 1 / ratio) / 20)
    return stereo * gain


def master(stereo, target_db, ceiling_db=-1.0):
    stereo = spectral(stereo, highpass(32, 2))
    stereo = compress(stereo)
    stereo = normalize_to(stereo, target_db)
    ceiling = 10 ** (ceiling_db / 20)
    # Soft limiter: transparent below ~70% of the ceiling.
    return ceiling * np.tanh(stereo / ceiling)


def mixdown(track, levels, sends, ir, reverb_return_db, loop, target_db):
    """Balances stems by loudness, adds reverb, wraps the tail for looping
    and masters."""
    dry = np.zeros((2, track.total))
    send = np.zeros((2, track.total))
    for name, stereo in track.stems.items():
        balanced = normalize_to(stereo, levels.get(name, -24))
        dry += balanced
        send += balanced * sends.get(name, 0.2)
    wet = convolve(send, ir)[:, : track.total + ir.shape[1]]
    wet = normalize_to(wet, reverb_return_db)
    full = np.zeros((2, max(track.total, wet.shape[1])))
    full[:, : track.total] += dry
    full[:, : wet.shape[1]] += wet
    if loop:
        # Fold everything past the loop point back onto the start, so the
        # reverb from the end rings into the beginning of the next pass.
        body = full[:, : track.length].copy()
        overhang = full[:, track.length:]
        while overhang.shape[1] > 0:
            span = min(track.length, overhang.shape[1])
            body[:, :span] += overhang[:, :span]
            overhang = overhang[:, span:]
        full = body
    else:
        # Let the tail ring out, then trim trailing near-silence.
        energy = np.abs(full).max(axis=0)
        audible = np.nonzero(energy > 1e-4)[0]
        end = audible[-1] + secs(0.1) if len(audible) else full.shape[1]
        full = full[:, :end]
        fade = min(secs(0.5), full.shape[1])
        full[:, -fade:] *= np.linspace(1, 0, fade)
    return master(full, target_db)


# ---------------------------------------------------------------------------
# The leitmotif
# ---------------------------------------------------------------------------

# (note, beats). Eight bars of 4/4, one chord per bar (bar 7 splits).
FATE_THEME = [
    ("D4", 1), ("A4", 2), ("G4", 0.5), ("F4", 0.5),
    ("E4", 3), ("C4", 1),
    ("D4", 1), ("F4", 1), ("Bb4", 1), ("A4", 1),
    ("A4", 4),
    ("D5", 2), ("C5", 1), ("Bb4", 1),
    ("A4", 1.5), ("G4", 0.5), ("F4", 2),
    ("G4", 1), ("Bb4", 1), ("A4", 1), ("C#5", 1),
    ("D5", 4),
]

# Chord per half bar across the theme, as (bass, [voicing]).
CHORDS = {
    "Dm": ("D2", ["D3", "A3", "D4", "F4"]),
    "C": ("C2", ["C3", "G3", "C4", "E4"]),
    "Bb": ("Bb1", ["Bb2", "F3", "Bb3", "D4"]),
    "A": ("A1", ["A2", "E3", "A3", "C#4"]),
    "F": ("F2", ["F2", "C3", "F3", "A3"]),
    "Gm": ("G1", ["G2", "D3", "G3", "Bb3"]),
    "Eb": ("Eb2", ["Eb3", "G3", "Bb3", "Eb4"]),
}
THEME_HARMONY = ["Dm", "Dm", "C", "C", "Bb", "Bb", "A", "A", "Bb", "Bb", "F", "F", "Gm", "A", "Dm", "Dm"]


def transpose(note, semitones):
    return midi(note) + semitones


def arpeggio_pattern(chord):
    """Eight eighth-notes rising and falling through a chord."""
    bass, voicing = CHORDS[chord]
    root = midi(voicing[0])
    tones = sorted({midi(v) for v in voicing} | {root + 12, root + 19})
    up = tones[:5]
    return up + up[-2:0:-1][:3]


# ---------------------------------------------------------------------------
# Pieces
# ---------------------------------------------------------------------------

def main_theme():
    """Menu: slow, mournful, hopeful at the edges. Loops seamlessly."""
    bpm = 68
    beat = 60 / bpm
    bar = 4 * beat
    bars = 26
    track = Track(bars * bar, tail=6, seed=101)
    r = track.rng

    def at(bar_index, beat_offset=0.0):
        return bar_index * bar + beat_offset * beat

    # Opening gong and a low D drone that underpins the whole loop.
    track.add("perc", gong(hz("D2") * 0.5, 9, 1.0, r), at(0), pan=0.0)
    track.add("drone", drone(hz("D1"), bars * bar, 1.0, r), 0)
    track.add("drone", drone(hz("A1"), bars * bar, 0.45, r), 0)

    # Music box hints at the motif over the drone.
    for note, beat_at in [("D5", 0), ("A5", 1.5), ("G5", 3.5), ("F5", 4), ("E5", 5)]:
        track.add("bells", bell(hz(note), 1, 0.8, r), at(0, beat_at), pan=0.35)

    harmony_menu = THEME_HARMONY  # 16 half-bars = 8 bars

    def pads(first_bar, velocity, choir_layer):
        for half, chord in enumerate(harmony_menu):
            start = at(first_bar) + half * 2 * beat
            bass, voicing = CHORDS[chord]
            for note in voicing:
                track.add_wide("strings", lambda n=note: strings(hz(n), 2 * beat, velocity, r, attack=0.5), start)
            if choir_layer:
                for note in voicing[1:]:
                    track.add_wide("choir", lambda n=note: choir(hz(transpose(n, 12)), 2 * beat, 0.8, r), start,
                                   width=0.8)
            track.add("bass", strings(hz(bass), 2 * beat, 0.9, r, attack=0.3, voices=2), start, pan=0.0)

    def harp_line(first_bar, velocity):
        for half, chord in enumerate(harmony_menu):
            pattern = arpeggio_pattern(chord)
            for step in range(4):
                note = pattern[(half % 2) * 4 + step]
                start = at(first_bar) + half * 2 * beat + step * beat * 0.5
                track.add("harp", harp(hz(note), beat, velocity * (1.0 if step == 0 else 0.8), r),
                          start, pan=-0.3 + 0.1 * step)

    def melody(first_bar, instrument, octave, stem, pan, velocity):
        position = 0.0
        for note, beats in FATE_THEME:
            start = at(first_bar) + position * beat
            track.add(stem, instrument(hz(transpose(note, octave)), beats * beat * 0.97, velocity, r), start,
                      pan=pan)
            position += beats

    # Bars 1-8: harp enters; theme on solo cello.
    harp_line(1, 0.7)
    harp_line(9, 0.75)
    pads(1, 0.5, choir_layer=False)
    melody(1, solo_cello, -12, "lead", -0.1, 0.9)

    # Bars 9-16: the theme passes to the choir, music box doubles above.
    pads(9, 0.6, choir_layer=True)
    melody(9, choir, 0, "choir_lead", 0.0, 0.9)
    position = 0.0
    for note, beats in FATE_THEME:
        if beats >= 2:
            track.add("bells", bell(hz(transpose(note, 12)), 1, 0.55, r), at(9) + position * beat, pan=0.35)
        position += beats
    for b in range(9, 17):
        # Heartbeat: a soft double pulse on the downbeat.
        track.add("perc", taiko(0.55, r, pitch=58), at(b), pan=0)
        track.add("perc", taiko(0.35, r, pitch=58), at(b, 0.45), pan=0)

    # Bars 17-20: the lift. Bb - F - Gm - A, strings swell, bells ring the motif wide.
    for i, chord in enumerate(["Bb", "F", "Gm", "A"]):
        bass, voicing = CHORDS[chord]
        start = at(17 + i)
        for note in voicing:
            track.add_wide("strings", lambda n=note: strings(hz(transpose(n, 12)), bar, 0.75, r, attack=0.9), start)
        track.add("bass", strings(hz(bass), bar, 1.0, r, attack=0.4, voices=2), start)
        track.add("perc", taiko(0.7, r, pitch=52), start)
    for note, b, beat_at in [("D5", 17, 0), ("A5", 17, 2), ("G5", 18, 0), ("F5", 18, 2), ("E5", 19, 0),
                             ("C#5", 20, 0), ("E5", 20, 2)]:
        track.add("bells", bell(hz(note), 2, 0.7, r), at(b, beat_at), pan=0.4)
    track.add("perc", cymbal_swell(bar, 0.5, r), at(19), pan=0.2)

    # Bars 21-25: settle home on D minor; the motif, slower, on cello, then
    # only the drone, which carries into the gong at the top of the loop.
    for i in range(4):
        bass, voicing = CHORDS["Dm"]
        for note in voicing:
            track.add_wide("strings", lambda n=note: strings(hz(n), bar, 0.45 - 0.08 * i, r, attack=0.6),
                           at(21 + i))
    for note, b, beats in [("D3", 21, 2), ("A3", 21.5, 2), ("G3", 22, 1), ("F3", 22.25, 1), ("E3", 22.5, 2),
                           ("D3", 23, 7)]:
        track.add("lead", solo_cello(hz(note), beats * beat, 0.7, r), b * bar, pan=-0.1)
    for step, note in enumerate(arpeggio_pattern("Dm")):
        track.add("harp", harp(hz(note), beat, 0.5, r), at(23, step * 0.5), pan=-0.2)

    levels = {"drone": -30, "strings": -22, "bass": -25, "harp": -23, "bells": -24, "lead": -17,
              "choir": -24, "choir_lead": -18, "perc": -21}
    sends = {"drone": 0.1, "strings": 0.5, "bass": 0.2, "harp": 0.45, "bells": 0.7, "lead": 0.4,
             "choir": 0.7, "choir_lead": 0.6, "perc": 0.4}
    for name, gain in [("choir", peaks([(700, 1.0, 0.8), (1150, 0.7, 0.7), (2600, 0.35, 0.6)], 0.08)),
                       ("choir_lead", peaks([(750, 1.0, 0.8), (1200, 0.75, 0.7), (2700, 0.35, 0.6)], 0.08)),
                       ("strings", chain(lowpass(3800, 2), highpass(70))),
                       ("lead", chain(lowpass(3200, 2), peaks([(260, 0.5, 1), (1100, 0.35, 1)], 1.0))),
                       ("bass", lowpass(900, 2))]:
        if name in track.stems:
            track.stems[name] = spectral(track.stems[name], gain)
    ir = impulse_response(3.8, 0.04, 2600, seed=7, width=1.0)
    return mixdown(track, levels, sends, ir, reverb_return_db=-20, loop=True, target_db=-17)


def battle_theme():
    """Ashen Wilds: driving, relentless, with the Fate motif on horns and
    choir. Loops seamlessly."""
    bpm = 140
    beat = 60 / bpm
    bar = 4 * beat
    bars = 52
    track = Track(bars * bar, tail=4, seed=202)
    r = track.rng

    def at(bar_index, beat_offset=0.0):
        return bar_index * bar + beat_offset * beat

    def ostinato(first_bar, chords, velocity=1.0):
        # Eighth notes on the root with octave kicks: the engine of the piece.
        pattern = [0, 0, 12, 0, 0, 12, 0, 10]
        for i, chord in enumerate(chords):
            bass = midi(CHORDS[chord][0])
            root = bass + 12 if bass < midi("C2") else bass
            for step, offset in enumerate(pattern):
                accent = 1.0 if step in (0, 3, 6) else 0.72
                track.add("ostinato", low_strings(hz(root + offset), beat * 0.42, velocity * accent, r),
                          at(first_bar + i, step * 0.5), pan=-0.15)

    def groove(first_bar, count, full=True):
        for b in range(first_bar, first_bar + count):
            track.add("drums", taiko(1.0, r, pitch=62), at(b, 0))
            track.add("drums", taiko(0.7, r, pitch=62), at(b, 1.5))
            track.add("drums", taiko(0.9, r, pitch=70), at(b, 2.5))
            if full:
                track.add("drums", frame_drum(0.8, r), at(b, 1), pan=0.2)
                track.add("drums", frame_drum(0.9, r), at(b, 3), pan=0.2)
                for s in range(8):
                    track.add("shaker", shaker(0.9 if s % 2 else 0.6, r), at(b, s * 0.5), pan=0.45)
            if b % 4 == 3:
                for s, pitch in enumerate([150, 130, 115, 100]):
                    track.add("drums", tom(0.8, r, pitch), at(b, 2 + s * 0.5), pan=-0.3 + 0.2 * s)

    def stabs(first_bar, chords):
        for i, chord in enumerate(chords):
            for note in CHORDS[chord][1]:
                track.add("brass", horn(hz(transpose(note, 12)), beat * 0.6, 0.9, r), at(first_bar + i), pan=0.1)

    def pads(first_bar, chords, beats_each, stem="pad", velocity=0.6, octave=0, voice=strings):
        for i, chord in enumerate(chords):
            for note in CHORDS[chord][1]:
                track.add_wide(stem, lambda n=note: voice(hz(transpose(n, octave)), beats_each * beat, velocity, r,
                                                          attack=0.25), at(first_bar) + i * beats_each * beat)

    def theme(first_bar, instrument, octave, stem, pan, velocity):
        # The motif at half speed against the doubled tempo: it rides over
        # the drive instead of racing it.
        position = 0.0
        for note, beats in FATE_THEME:
            track.add(stem, instrument(hz(transpose(note, octave)), beats * 2 * beat * 0.95, velocity, r),
                      at(first_bar) + position * 2 * beat, pan=pan)
            position += beats

    # At half speed each half-bar chord of the theme lasts a full bar.
    theme_chords = list(THEME_HARMONY)
    a_chords = ["Dm", "Dm", "Bb", "C", "Dm", "Dm", "Bb", "A"]
    bridge = ["Gm", "Gm", "Bb", "Bb", "F", "F", "A", "A"]

    # Bars 0-3: drums and drive alone.
    ostinato(0, ["Dm"] * 4, 0.9)
    groove(0, 4, full=False)
    track.add("drums", cymbal_swell(bar, 0.7, r), at(3))

    # Bars 4-11: full groove, brass stabs, choir pad.
    ostinato(4, a_chords)
    groove(4, 8)
    stabs(4, a_chords)
    pads(4, a_chords, 4, stem="choir", velocity=0.5, voice=choir)

    # Bars 12-27: the Fate theme on horns.
    ostinato(12, theme_chords)
    groove(12, 16)
    pads(12, theme_chords, 4, velocity=0.5)
    theme(12, horn, 0, "lead", -0.05, 1.0)

    # Bars 28-35: bridge. Half-time drums, tremolo strings, choir climbs.
    ostinato(28, bridge, 0.75)
    for b in range(28, 36):
        track.add("drums", taiko(1.0, r, pitch=56), at(b, 0))
        track.add("drums", taiko(0.8, r, pitch=62), at(b, 2))
    for i, chord in enumerate(bridge):
        for note in CHORDS[chord][1][1:]:
            for s in range(16):
                track.add("tremolo", strings(hz(transpose(note, 12)), beat * 0.22, 0.45 + 0.03 * i, r,
                                             attack=0.01, release=0.08, voices=2), at(28 + i, s * 0.25),
                          pan=0.3)
    for note, b, beats in [("G4", 28, 8), ("A4", 30, 8), ("F4", 32, 4), ("A4", 33, 4), ("C#5", 34, 4),
                           ("E5", 35, 4)]:
        track.add("choir_lead", choir(hz(note), beats * beat, 0.9, r, attack=0.3), at(b), pan=0.0)
    for s in range(16):
        track.add("drums", tom(0.4 + s * 0.04, r, 125 - s * 2), at(35, s * 0.25), pan=-0.2 + 0.025 * s)
    track.add("drums", cymbal_swell(bar, 0.9, r), at(35))

    # Bars 36-51: the theme returns, on choir and strings together, horns
    # answering with long counter-notes.
    ostinato(36, theme_chords)
    groove(36, 16)
    theme(36, choir, 0, "choir_lead", 0.0, 1.0)
    theme(36, lambda f, d, v, g: strings(f, d, v, g, attack=0.08, release=0.4), 0, "lead", 0.1, 0.8)
    for i, chord in enumerate(theme_chords):
        voicing = CHORDS[chord][1]
        track.add("brass", horn(hz(transpose(voicing[-1], 0)), 4 * beat * 0.9, 0.7, r), at(36 + i), pan=-0.35)
    stabs(36, theme_chords)

    levels = {"ostinato": -19, "drums": -16, "shaker": -30, "brass": -22, "pad": -25, "choir": -24,
              "lead": -17, "choir_lead": -19, "tremolo": -26}
    sends = {"ostinato": 0.15, "drums": 0.25, "shaker": 0.2, "brass": 0.35, "pad": 0.45, "choir": 0.6,
             "lead": 0.35, "choir_lead": 0.55, "tremolo": 0.4}
    for name, gain in [("choir", peaks([(700, 1.0, 0.8), (1150, 0.7, 0.7), (2600, 0.35, 0.6)], 0.08)),
                       ("choir_lead", peaks([(750, 1.0, 0.8), (1200, 0.75, 0.7), (2700, 0.35, 0.6)], 0.08)),
                       ("ostinato", chain(lowpass(1900, 2), highpass(45))),
                       ("pad", lowpass(3500, 2)),
                       ("tremolo", chain(lowpass(4500, 2), highpass(200))),
                       ("lead", lowpass(5000, 1)),
                       ("brass", lowpass(4200, 1))]:
        if name in track.stems:
            track.stems[name] = spectral(track.stems[name], gain)
    ir = impulse_response(2.3, 0.025, 3200, seed=11, width=0.9)
    return mixdown(track, levels, sends, ir, reverb_return_db=-21, loop=True, target_db=-15)


def defeat_sting():
    """Fate sealed: a heavy blow, a falling chord, and the motif on a lone
    music box that never quite resolves upward."""
    beat = 60 / 56
    track = Track(9, tail=5, seed=303)
    r = track.rng
    track.add("perc", taiko(1.0, r, pitch=48, length=2.2), 0)
    track.add("perc", gong(hz("D2") * 0.5, 8, 0.9, r), 0.02)
    for chord, start, length in [("Bb", 0.0, 2 * beat), ("A", 2 * beat, 2 * beat), ("Dm", 4 * beat, 5 * beat)]:
        for note in CHORDS[chord][1]:
            track.add_wide("choir", lambda n=note: choir(hz(n), length, 0.8, r, attack=0.4, release=1.4), start,
                           width=0.7)
        track.add("bass", strings(hz(CHORDS[chord][0]), length, 0.9, r, attack=0.2, voices=2), start)
    for note, beat_at in [("D5", 1.0), ("A5", 2.0), ("G5", 3.5), ("F5", 4.0), ("E5", 4.5), ("D5", 6.0)]:
        track.add("bells", bell(hz(note), 1, 0.8, r, decay=3.0), beat_at * beat, pan=0.25)
    levels = {"perc": -18, "choir": -20, "bass": -24, "bells": -20}
    sends = {"perc": 0.4, "choir": 0.7, "bass": 0.3, "bells": 0.8}
    track.stems["choir"] = spectral(track.stems["choir"],
                                    peaks([(650, 1.0, 0.8), (1080, 0.7, 0.7), (2500, 0.3, 0.6)], 0.08))
    ir = impulse_response(4.2, 0.05, 2400, seed=13)
    return mixdown(track, levels, sends, ir, reverb_return_db=-19, loop=False, target_db=-17)


def ashen_wind():
    """A 48-second seamless bed: shifting wind, a far-off rumble, embers."""
    seconds = 48
    n = secs(seconds)
    rng = np.random.default_rng(404)
    t = np.arange(n) / SR
    out = np.zeros((2, n))
    # Every modulation completes whole cycles over the loop, so it's seamless.
    for ch in range(2):
        for center, width, level, cycles in [(260, 1.2, 1.0, 3), (520, 1.0, 0.7, 5), (1100, 0.9, 0.4, 7),
                                             (2300, 0.8, 0.18, 11)]:
            band = spectral(rng.standard_normal(n), bandpass(center, width), circular=True)
            lfo = 0.55 + 0.45 * np.sin(TAU * cycles * t / seconds + rng.uniform(0, TAU))
            gust = 0.7 + 0.3 * np.sin(TAU * (cycles + 2) * t / seconds + rng.uniform(0, TAU))
            out[ch] += band * lfo * gust * level
        rumble = spectral(rng.standard_normal(n), lowpass(70, 2), circular=True)
        out[ch] += rumble * 2.5 * (0.6 + 0.4 * np.sin(TAU * 2 * t / seconds + ch))
    # Ember crackle: sparse clicks, a little different left and right.
    for _ in range(140):
        position = int(rng.uniform(0, n - secs(0.02)))
        click = spectral(rng.standard_normal(secs(0.015)), highpass(2500, 2)) * np.exp(-np.arange(secs(0.015)) / 80)
        pan = rng.uniform(-0.8, 0.8)
        left, right = pan_gains(pan)
        level = rng.uniform(0.2, 0.8)
        out[0, position: position + len(click)] += click * left * level
        out[1, position: position + len(click)] += click * right * level
    out = normalize_to(out, -26)
    return np.tanh(out * 1.2) / 1.2


# ---------------------------------------------------------------------------
# Sound effects (mono)
# ---------------------------------------------------------------------------

def band_noise(n, rng, center, width=1.0):
    return spectral(rng.standard_normal(n), bandpass(center, width))


def sweep_noise(n, rng, start_hz, end_hz, bands=10):
    """Noise whose centre frequency moves from start to end."""
    t = np.linspace(0, 1, n)
    centers = np.geomspace(min(start_hz, end_hz) * 0.8, max(start_hz, end_hz) * 1.25, bands)
    path = np.geomspace(start_hz, end_hz, n) if start_hz != end_hz else np.full(n, start_hz)
    out = np.zeros(n)
    for center in centers:
        weight = np.exp(-0.5 * (np.log2(path / center) / 0.35) ** 2)
        out += band_noise(n, rng, center, 0.7) * weight
    return out


def fade_edges(x, fade_in=0.002, fade_out=0.01):
    a = min(secs(fade_in), len(x))
    b = min(secs(fade_out), len(x))
    x = x.copy()
    if a:
        x[:a] *= np.linspace(0, 1, a)
    if b:
        x[-b:] *= np.linspace(1, 0, b)
    return x


def small_room(x, amount=0.2, seconds=0.6, seed=0):
    ir = impulse_response(seconds, 0.008, 5000, seed=seed, width=0.0)[:1]
    wet = convolve(np.vstack([x, x]), np.vstack([ir, ir]))[0]
    wet /= max(np.abs(wet).max(), 1e-9)
    out = np.zeros(len(wet))
    out[: len(x)] += x / max(np.abs(x).max(), 1e-9)
    return out + wet * amount


def normalize_peak(x, peak_db=-1.0):
    return x / max(np.abs(x).max(), 1e-9) * 10 ** (peak_db / 20)


def sfx_swing(variant):
    rng = np.random.default_rng(500 + variant)
    length = 0.26 + 0.03 * variant
    n = secs(length)
    t = np.arange(n) / SR
    start, end = [(700, 2600), (600, 2200), (800, 3000)][variant]
    whoosh = sweep_noise(n, rng, start, end)
    peak = [0.085, 0.1, 0.075][variant]
    amp = np.where(t < peak, (t / peak) ** 2, np.exp(-(t - peak) / 0.055))
    # A faint steel ring riding the air.
    ring = sum(np.sin(TAU * f * t) * np.exp(-t / 0.09) for f in (3150 + 120 * variant, 4730))
    body = whoosh * amp + 0.05 * ring * amp
    return normalize_peak(fade_edges(body), -3)


def sfx_hit(variant):
    rng = np.random.default_rng(600 + variant)
    n = secs(0.2)
    t = np.arange(n) / SR
    pitch = [105, 92, 118][variant]
    thump = np.sin(TAU * np.cumsum(pitch * (1 + 1.2 * np.exp(-t / 0.012))) / SR) * np.exp(-t / 0.05)
    crack = spectral(rng.standard_normal(n), chain(lowpass(2600, 2), highpass(300))) * np.exp(-t / 0.012)
    flesh = band_noise(n, rng, [850, 700, 1000][variant], 1.2) * np.exp(-t / 0.035)
    return normalize_peak(fade_edges(thump + 0.8 * crack + 0.6 * flesh), -1.5)


def sfx_hit_critical():
    rng = np.random.default_rng(650)
    n = secs(0.5)
    t = np.arange(n) / SR
    base = fit(sfx_hit(0), n) * 1.2
    ring = sum(level * np.sin(TAU * f * t) * np.exp(-t / d)
               for f, level, d in [(1240, 0.5, 0.16), (2890, 0.35, 0.12), (4130, 0.25, 0.08)])
    sub = np.sin(TAU * 55 * t) * np.exp(-t / 0.12)
    return normalize_peak(fade_edges(base + 0.45 * ring + 0.6 * sub), -1)


def formant_voice(n, rng, f_start, f_end, formants):
    freq = np.geomspace(f_start, f_end, n)
    growl = 1 + 0.25 * np.sin(TAU * 31 * np.arange(n) / SR)
    source = saw(np.cumsum(freq * growl) / SR, freq * growl / SR)
    return spectral(source, peaks(formants, 0.05))


def sfx_goblin_death(variant):
    rng = np.random.default_rng(700 + variant)
    n = secs(0.34)
    t = np.arange(n) / SR
    starts = [(260, 95), (300, 110)][variant]
    voice = formant_voice(n, rng, starts[0], starts[1], [(620, 1.0, 0.7), (1050, 0.6, 0.6), (2400, 0.2, 0.5)])
    voice *= np.clip(t / 0.01, 0, 1) * np.exp(-t / 0.09)
    thud = np.sin(TAU * np.cumsum(80 * (1 + np.exp(-t / 0.02))) / SR) * np.exp(-np.maximum(t - 0.06, 0) / 0.07)
    thud *= t > 0.06
    return normalize_peak(fade_edges(0.8 * voice + 0.7 * thud), -3)


def sfx_player_hurt():
    rng = np.random.default_rng(800)
    n = secs(0.32)
    t = np.arange(n) / SR
    thump = np.sin(TAU * np.cumsum(88 * (1 + 0.9 * np.exp(-t / 0.02))) / SR) * np.exp(-t / 0.08)
    leather = band_noise(n, rng, 1400, 1.5) * np.exp(-t / 0.03)
    grunt = formant_voice(n, rng, 150, 112, [(540, 1.0, 0.7), (900, 0.5, 0.6)])
    grunt *= np.clip((t - 0.015) / 0.02, 0, 1) * np.exp(-t / 0.08)
    return normalize_peak(fade_edges(thump + 0.5 * leather + 0.45 * grunt), -1)


def sfx_player_death():
    rng = np.random.default_rng(850)
    n = secs(1.6)
    t = np.arange(n) / SR
    boom = np.sin(TAU * np.cumsum(58 * (1 + 0.8 * np.exp(-t / 0.08))) / SR) * np.exp(-t / 0.45)
    rumble = spectral(rng.standard_normal(n), lowpass(300, 2)) * np.exp(-t / 0.35)
    body = boom + 0.6 * rumble
    return normalize_peak(fade_edges(small_room(body, 0.25, 1.2, seed=3)[:n], 0.002, 0.2), -1)


def sfx_bow_shot():
    rng = np.random.default_rng(900)
    n = secs(0.34)
    t = np.arange(n) / SR
    string = fit(karplus(196, 0.34, rng, brightness=0.9, t60=0.25), n)
    air = sweep_noise(n, rng, 4200, 2200) * np.exp(-t / 0.05) * np.clip(t / 0.01, 0, 1)
    return normalize_peak(fade_edges(string + 0.5 * air), -3)


def sfx_arcane_cast():
    rng = np.random.default_rng(950)
    n = secs(0.42)
    t = np.arange(n) / SR
    freq = np.geomspace(380, 900, n)
    phase = TAU * np.cumsum(freq) / SR
    shimmer = np.sin(phase + 2.2 * np.exp(-t / 0.15) * np.sin(phase * 2.01))
    sparkle = sum(np.sin(TAU * f * t + rng.uniform(0, TAU)) for f in rng.uniform(2500, 6000, 5))
    amp = np.clip(t / 0.03, 0, 1) * np.exp(-t / 0.14)
    body = (shimmer + 0.12 * sparkle) * amp
    return normalize_peak(fade_edges(small_room(body, 0.35, 0.8, seed=5)[:n + secs(0.2)]), -3)


def sfx_arcane_burst():
    rng = np.random.default_rng(975)
    n = secs(0.65)
    t = np.arange(n) / SR
    blast = sweep_noise(n, rng, 3800, 450) * np.exp(-t / 0.12) * np.clip(t / 0.004, 0, 1)
    thump = np.sin(TAU * np.cumsum(70 * (1 + np.exp(-t / 0.02))) / SR) * np.exp(-t / 0.1)
    chime = sum(np.sin(TAU * f * t) * np.exp(-t / 0.2) for f in (880, 1319, 1760))
    body = blast + 0.8 * thump + 0.12 * chime
    return normalize_peak(fade_edges(small_room(body, 0.3, 1.0, seed=6)[:n + secs(0.3)], 0.002, 0.05), -1)


def sfx_ui_confirm():
    rng = np.random.default_rng(1000)
    n = secs(0.7)
    body = np.zeros(n)
    body += fit(bell(hz("A5"), 1, 0.8, rng, decay=0.8, ratio=2.0, index=0.8), n)
    late = fit(bell(hz("D6"), 1, 0.7, rng, decay=0.8, ratio=2.0, index=0.8), n - secs(0.06))
    body[secs(0.06):] += late
    return normalize_peak(fade_edges(small_room(body, 0.25, 0.9, seed=8)[:n], 0.001, 0.1), -6)


def sfx_ui_back():
    rng = np.random.default_rng(1050)
    n = secs(0.35)
    t = np.arange(n) / SR
    tick = band_noise(n, rng, 1800, 1.0) * np.exp(-t / 0.008)
    tone = fit(bell(hz("D5"), 1, 0.6, rng, decay=0.35, ratio=2.0, index=0.5), n)
    return normalize_peak(fade_edges(0.6 * tick + tone, 0.001, 0.05), -7)



# --- Skills and progression -------------------------------------------------

def tone_sweep(n, f_start, f_end, decay):
    t = np.arange(n) / SR
    freq = np.geomspace(f_start, f_end, n)
    return np.sin(TAU * np.cumsum(freq) / SR) * np.exp(-t / decay)


def sfx_ember(step):
    """Soft chimes on a D minor pentatonic, climbing with quick pickups."""
    rng = np.random.default_rng(1100 + step)
    notes = ["D6", "F6", "G6", "A6", "C7"]
    n = secs(0.45)
    body = fit(bell(hz(notes[step]), 1, 0.6, rng, decay=0.35, ratio=3.0, index=0.6), n)
    return normalize_peak(fade_edges(body, 0.001, 0.08), -8)


def sfx_level_up():
    """A burst of fate: a low boom, a rising rush, and the Fate motif on bells."""
    rng = np.random.default_rng(1200)
    n = secs(2.2)
    t = np.arange(n) / SR
    boom = tone_sweep(n, 110, 48, 0.5)
    rush = sweep_noise(n, rng, 400, 5200) * np.clip(t / 0.25, 0, 1) * np.exp(-np.maximum(t - 0.25, 0) / 0.18)
    body = 0.9 * boom + 0.35 * rush
    for offset, note in zip([0.12, 0.3, 0.46, 0.62], ["D5", "A5", "G5", "F5"]):
        start = secs(offset)
        chime = fit(bell(hz(note), 1.4, 0.9, rng, decay=1.2, ratio=2.0, index=1.0), n - start)
        body[start:] += 0.55 * chime
    for note in ["D4", "A4", "D5", "F5"]:
        body += 0.12 * mono(strings(hz(note), 1.6, 0.5, rng, attack=0.08, release=0.6), n)
    return normalize_peak(fade_edges(small_room(body, 0.35, 1.6, seed=12)[:n], 0.002, 0.3), -1)


def mono(signal, n):
    """First channel of a possibly stereo render, fitted to n samples."""
    data = np.asarray(signal)
    if data.ndim > 1:
        data = data[0]
    return fit(data, n)


def sfx_ui_skill_learn():
    rng = np.random.default_rng(1250)
    n = secs(0.55)
    pluck = mono(harp(hz("A4"), 0.5, 0.9, rng), n)
    shimmer = mono(bell(hz("E6"), 1, 0.5, rng, decay=0.4, ratio=3.0, index=0.7), n)
    return normalize_peak(fade_edges(small_room(pluck + 0.5 * shimmer, 0.3, 0.8, seed=13)[:n], 0.001, 0.1), -6)


def sfx_ui_tree_open():
    rng = np.random.default_rng(1260)
    n = secs(0.8)
    t = np.arange(n) / SR
    page = sweep_noise(n, rng, 900, 3200) * np.exp(-t / 0.08) * np.clip(t / 0.02, 0, 1)
    chord = sum(mono(bell(hz(note), 1, 0.5, rng, decay=0.6, ratio=2.0, index=0.5), n) for note in ("D5", "F5", "A5"))
    return normalize_peak(fade_edges(0.4 * page + 0.5 * chord, 0.001, 0.15), -7)


def sfx_ab_impact():
    rng = np.random.default_rng(1300)
    n = secs(0.5)
    t = np.arange(n) / SR
    thump = tone_sweep(n, 140, 45, 0.16)
    crack = spectral(rng.standard_normal(n), chain(lowpass(3000, 2), highpass(200))) * np.exp(-t / 0.03)
    rubble = band_noise(n, rng, 500, 1.4) * np.exp(-t / 0.12)
    return normalize_peak(fade_edges(thump + 0.7 * crack + 0.5 * rubble, 0.001, 0.05), -1)


def sfx_ab_fire():
    rng = np.random.default_rng(1310)
    n = secs(0.8)
    t = np.arange(n) / SR
    whoomp = sweep_noise(n, rng, 300, 1800) * np.clip(t / 0.05, 0, 1) * np.exp(-t / 0.25)
    crackle = (rng.random(n) > 0.997) * rng.uniform(-1, 1, n)
    crackle = spectral(crackle, highpass(1500)) * np.exp(-t / 0.4)
    body = whoomp + 0.6 * tone_sweep(n, 90, 50, 0.2) + 1.5 * crackle
    return normalize_peak(fade_edges(body, 0.002, 0.1), -2)


def sfx_ab_frost():
    rng = np.random.default_rng(1320)
    n = secs(0.8)
    t = np.arange(n) / SR
    crystal = sum(np.sin(TAU * f * t + rng.uniform(0, TAU)) * np.exp(-t / rng.uniform(0.15, 0.4))
                  for f in rng.uniform(2200, 7000, 9))
    hiss = sweep_noise(n, rng, 6000, 2500) * np.exp(-t / 0.2) * np.clip(t / 0.01, 0, 1)
    crack = band_noise(n, rng, 2500, 1.0) * np.exp(-t / 0.015)
    return normalize_peak(fade_edges(0.25 * crystal + 0.6 * hiss + crack, 0.001, 0.1), -3)


def sfx_ab_lightning():
    rng = np.random.default_rng(1330)
    n = secs(0.55)
    t = np.arange(n) / SR
    zap = spectral(rng.standard_normal(n), highpass(1200)) * np.exp(-t / 0.05)
    freq = np.full(n, 110.0)
    buzz = spectral(saw(np.cumsum(freq) / SR, freq / SR) * np.exp(-t / 0.12), lowpass(2500, 2))
    boom = tone_sweep(n, 90, 40, 0.18)
    return normalize_peak(fade_edges(zap + 0.4 * buzz + 0.6 * boom, 0.001, 0.05), -2)


def sfx_ab_holy():
    rng = np.random.default_rng(1340)
    n = secs(1.0)
    voices = sum(mono(choir(hz(note), 0.9, 0.6, rng, attack=0.03, release=0.5), n) for note in ("D5", "A5", "D6"))
    chime = mono(bell(hz("A6"), 1, 0.6, rng, decay=0.6, ratio=2.0, index=0.8), n)
    body = 0.5 * voices + 0.5 * chime + 0.4 * tone_sweep(n, 120, 60, 0.15)
    return normalize_peak(fade_edges(small_room(body, 0.4, 1.2, seed=14)[:n], 0.002, 0.2), -2)


def sfx_ab_shadow():
    rng = np.random.default_rng(1350)
    n = secs(0.8)
    t = np.arange(n) / SR
    rush = sweep_noise(n, rng, 2400, 250) * np.clip(t / 0.03, 0, 1) * np.exp(-t / 0.2)
    moan = formant_voice(n, rng, 120, 80, [(400, 1.0, 0.6), (800, 0.5, 0.6)]) * np.exp(-t / 0.3)
    return normalize_peak(fade_edges(rush + 0.35 * moan + 0.5 * tone_sweep(n, 70, 38, 0.3), 0.002, 0.1), -2)


def sfx_ab_nature():
    rng = np.random.default_rng(1360)
    n = secs(0.7)
    t = np.arange(n) / SR
    rustle = band_noise(n, rng, 2800, 1.6) * (0.6 + 0.4 * np.sin(TAU * 23 * t)) * np.exp(-t / 0.18)
    creak = tone_sweep(n, 180, 95, 0.25) * 0.6
    snap = band_noise(n, rng, 1200, 1.0) * np.exp(-t / 0.012)
    return normalize_peak(fade_edges(rustle + creak + snap, 0.001, 0.1), -3)


def sfx_ab_sonic():
    rng = np.random.default_rng(1370)
    n = secs(0.8)
    t = np.arange(n) / SR
    chord = sum(np.sin(TAU * hz(note) * t + 0.8 * np.sin(TAU * hz(note) * 1.007 * t))
                for note in ("D4", "G#4", "D5"))
    body = chord * np.clip(t / 0.01, 0, 1) * np.exp(-t / 0.28)
    swell = sweep_noise(n, rng, 800, 300) * np.exp(-t / 0.1)
    return normalize_peak(fade_edges(small_room(0.4 * body + swell, 0.3, 0.9, seed=15)[:n], 0.001, 0.1), -3)


def sfx_ab_buff():
    """A short war-horn call."""
    rng = np.random.default_rng(1380)
    n = secs(0.9)
    call = mono(horn(hz("D4"), 0.7, 0.9, rng, attack=0.04, release=0.25), n)
    fifth = mono(horn(hz("A4"), 0.6, 0.7, rng, attack=0.06, release=0.25), n)
    return normalize_peak(fade_edges(small_room(call + 0.6 * fifth, 0.35, 1.0, seed=16)[:n], 0.002, 0.15), -3)


def sfx_summon():
    rng = np.random.default_rng(1390)
    n = secs(0.9)
    t = np.arange(n) / SR
    rise = sweep_noise(n, rng, 200, 1400) * np.clip(t / 0.3, 0, 1) * np.exp(-np.maximum(t - 0.3, 0) / 0.15)
    low = tone_sweep(n, 55, 85, 0.5)
    return normalize_peak(fade_edges(rise + 0.6 * low, 0.002, 0.15), -3)


def sfx_dash():
    rng = np.random.default_rng(1400)
    n = secs(0.3)
    t = np.arange(n) / SR
    whoosh = sweep_noise(n, rng, 500, 3500) * np.sin(np.pi * np.clip(t / 0.25, 0, 1))
    return normalize_peak(fade_edges(whoosh, 0.002, 0.03), -4)


def sfx_heal():
    rng = np.random.default_rng(1410)
    n = secs(0.7)
    body = sum(0.5 * mono(bell(hz(note), 1, 0.5, rng, decay=0.5, ratio=2.0, index=0.4), n)
               for note in ("A5", "D6", "F#6"))
    return normalize_peak(fade_edges(small_room(body, 0.35, 0.9, seed=17)[:n], 0.002, 0.15), -7)


def sfx_dodge():
    rng = np.random.default_rng(1420)
    n = secs(0.22)
    t = np.arange(n) / SR
    swish = sweep_noise(n, rng, 2500, 5000) * np.sin(np.pi * np.clip(t / 0.2, 0, 1)) ** 2
    return normalize_peak(fade_edges(swish, 0.002, 0.02), -6)


def sfx_keg_blast():
    rng = np.random.default_rng(1430)
    n = secs(1.1)
    t = np.arange(n) / SR
    boom = tone_sweep(n, 90, 30, 0.35)
    blast = spectral(rng.standard_normal(n), lowpass(3500, 2)) * np.exp(-t / 0.15)
    debris = spectral((rng.random(n) > 0.995) * rng.uniform(-1, 1, n), highpass(800)) * np.exp(-t / 0.5)
    return normalize_peak(fade_edges(boom + 0.8 * blast + 1.5 * debris, 0.001, 0.2), -1)


def sfx_shapeshift():
    rng = np.random.default_rng(1440)
    n = secs(0.9)
    t = np.arange(n) / SR
    growl = formant_voice(n, rng, 90, 70, [(350, 1.0, 0.6), (700, 0.6, 0.6), (1300, 0.3, 0.5)])
    growl *= np.clip(t / 0.08, 0, 1) * np.exp(-t / 0.35)
    rustle = band_noise(n, rng, 2600, 1.5) * np.exp(-t / 0.2)
    return normalize_peak(fade_edges(growl + 0.4 * rustle, 0.002, 0.15), -2)


# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

def write_wav(path, data):
    data = np.atleast_2d(data)
    rng = np.random.default_rng(1)
    # TPDF dither to 16 bit.
    dither = (rng.uniform(-0.5, 0.5, data.shape) + rng.uniform(-0.5, 0.5, data.shape)) / 32768
    pcm = np.clip(data + dither, -1, 1)
    ints = np.round(pcm * 32767).astype("<i2")
    interleaved = ints.T.reshape(-1)
    with wave.open(path, "wb") as handle:
        handle.setnchannels(data.shape[0])
        handle.setsampwidth(2)
        handle.setframerate(SR)
        handle.writeframes(interleaved.tobytes())


MUSIC = {
    "mus_menu_fate_lost": main_theme,
    "mus_battle_ashen_wilds": battle_theme,
    "mus_defeat": defeat_sting,
    "amb_ashen_wilds": ashen_wind,
}

EFFECTS = {
    "sfx_swing_1": lambda: sfx_swing(0),
    "sfx_swing_2": lambda: sfx_swing(1),
    "sfx_swing_3": lambda: sfx_swing(2),
    "sfx_hit_1": lambda: sfx_hit(0),
    "sfx_hit_2": lambda: sfx_hit(1),
    "sfx_hit_3": lambda: sfx_hit(2),
    "sfx_hit_critical": sfx_hit_critical,
    "sfx_goblin_death_1": lambda: sfx_goblin_death(0),
    "sfx_goblin_death_2": lambda: sfx_goblin_death(1),
    "sfx_player_hurt": sfx_player_hurt,
    "sfx_player_death": sfx_player_death,
    "sfx_bow_shot": sfx_bow_shot,
    "sfx_arcane_cast": sfx_arcane_cast,
    "sfx_arcane_burst": sfx_arcane_burst,
    "ui_confirm": sfx_ui_confirm,
    "ui_back": sfx_ui_back,
    "sfx_ember_1": lambda: sfx_ember(0),
    "sfx_ember_2": lambda: sfx_ember(1),
    "sfx_ember_3": lambda: sfx_ember(2),
    "sfx_ember_4": lambda: sfx_ember(3),
    "sfx_ember_5": lambda: sfx_ember(4),
    "sfx_level_up": sfx_level_up,
    "ui_skill_learn": sfx_ui_skill_learn,
    "ui_tree_open": sfx_ui_tree_open,
    "sfx_ab_impact": sfx_ab_impact,
    "sfx_ab_fire": sfx_ab_fire,
    "sfx_ab_frost": sfx_ab_frost,
    "sfx_ab_lightning": sfx_ab_lightning,
    "sfx_ab_holy": sfx_ab_holy,
    "sfx_ab_shadow": sfx_ab_shadow,
    "sfx_ab_nature": sfx_ab_nature,
    "sfx_ab_sonic": sfx_ab_sonic,
    "sfx_ab_buff": sfx_ab_buff,
    "sfx_summon": sfx_summon,
    "sfx_dash": sfx_dash,
    "sfx_heal": sfx_heal,
    "sfx_dodge": sfx_dodge,
    "sfx_keg_blast": sfx_keg_blast,
    "sfx_shapeshift": sfx_shapeshift,
}


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    default_out = os.path.normpath(os.path.join(here, "..", "..", "FateLost", "Resources", "Audio"))
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--out", default=default_out)
    parser.add_argument("--only", choices=["music", "sfx"], default=None)
    parser.add_argument("--name", default=None, help="render a single file by name")
    args = parser.parse_args()
    os.makedirs(args.out, exist_ok=True)

    jobs = {}
    if args.only != "sfx":
        jobs.update(MUSIC)
    if args.only != "music":
        jobs.update(EFFECTS)
    if args.name:
        jobs = {args.name: {**MUSIC, **EFFECTS}[args.name]}

    for name, render in jobs.items():
        started = time.time()
        audio = render()
        path = os.path.join(args.out, name + ".wav")
        write_wav(path, audio)
        data = np.atleast_2d(audio)
        seconds = data.shape[1] / SR
        peak = 20 * np.log10(max(np.abs(data).max(), 1e-9))
        print(f"{name:28s} {seconds:6.2f}s  peak {peak:6.1f} dBFS  rms {active_rms_db(data):6.1f} dB"
              f"  ({time.time() - started:.1f}s)", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
