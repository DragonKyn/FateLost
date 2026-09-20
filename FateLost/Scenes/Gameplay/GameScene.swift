import SpriteKit
import QuartzCore

/// Informational HUD values handed to SwiftUI. Published only on change.
struct GameplayHUDState: Equatable {
    var health: Double = 0
    var maxHealth: Double = 1
    var barrier: Double = 0
    var elapsedSeconds: Int = 0
    var wave: Int = 1
    var level: Int = 1
    /// Progress toward the next level, 0…1.
    var experienceFraction: Double = 0
    var unspentPoints: Int = 0
    var kills: Int = 0
    /// Living summons, and whether the player has sent them away.
    var allyCount: Int = 0
    var summonsDismissed = false
    /// True when the build has summons at all, so the control can hide.
    var hasSummons = false
    /// The champion holding the wave open, if any.
    var bossTitle: String?
    var bossHealthFraction: Double = 0
    /// Whole seconds left on a Shrine of Ruin's curse; zero when none.
    var curseSeconds: Int = 0
}

/// The build as the skill tree screen needs it. Published when it changes.
struct ProgressionSnapshot: Equatable {
    var level = 1
    var unspentPoints = 0
    var earnedPoints = 0
    var allocation = SkillAllocation()
    var abilitySlots: [AbilityID?] = Array(repeating: nil, count: AbilitySlots.count)
    var buildVersion = 0
    /// Relics carried, for the strip on the HUD and the pause screen.
    var relics = RelicInventory()

    var title: BuildTitle.Title { BuildTitle.title(for: allocation) }
}

/// How a run ended, for the summary screen.
struct RunSummary: Equatable {
    /// Whether the realm took the player, or the player took the realm.
    enum Outcome: Equatable {
        case defeated
        case conquered
    }

    let realm: RealmID
    let weapon: WeaponID
    let secondsSurvived: Int
    let stats: RunStats
    let level: Int
    let allocation: SkillAllocation
    var outcome: Outcome = .defeated
    var wave: Int = 1
    var relics = RelicInventory()
}

/// The gameplay scene.
///
/// A coordinator, not a god object: it owns no game rules. Each frame it
/// turns touches into a `PlayerIntent`, advances `GameSimulation` in fixed
/// steps, hands the resulting events to `CombatFeedback` and the resulting
/// state to focused renderers (ground, decorations, zones, pickups, enemies,
/// allies, projectiles, effects, player, camera, HUD). New gameplay belongs
/// in simulation systems; new visuals belong in renderers.
final class GameScene: SKScene {
    struct Dependencies {
        let tuning: GameTuning
        let settings: SettingsStore
        let developer: DeveloperOptions
        let audio: AudioManager
        let haptics: HapticsProviding
        /// Permanent bonuses from the Legacy board.
        var legacy: [StatModifier] = []
        /// Rerolls the relic codex adds to every find.
        var bonusRerolls = 0
        /// How the player chose to look.
        var hero = HeroAppearance.standard
    }

    private enum Timing {
        /// Seconds after the player falls before the summary appears.
        static let defeatSummaryDelay: TimeInterval = 2.2
        /// Simulation speed while the player's fall plays out.
        static let defeatTimeScale: Double = 0.35
        /// Health fraction below which the danger vignette pulses.
        static let lowHealthFraction: Double = 0.3
    }

    // MARK: State

    private(set) var simulation: GameSimulation
    private let dependencies: Dependencies
    private var tuning: GameTuning { dependencies.tuning }
    private let projection: IsometricProjection
    private var renderFrame: WrappedRenderFrame
    private var timestep: FixedTimestep
    private var lastUpdateTime: TimeInterval?
    /// Real seconds of hit-stop remaining; the simulation holds still.
    private var hitStopRemaining: TimeInterval = 0
    private var summaryDelivered = false
    /// Scene time used for idle animation, advanced only while unpaused.
    private var animationTime: TimeInterval = 0
    /// Ability buttons pressed since the last simulation step.
    private var pendingAbilityPresses: UInt8 = 0

    /// Freezes simulation while leaving rendering alive (pause menu, level-up).
    var isGameplayPaused = false {
        didSet {
            lastUpdateTime = nil
            timestep.reset()
        }
    }

    /// Called on the main thread whenever HUD-relevant values change.
    var onHUDStateChange: ((GameplayHUDState) -> Void)?
    /// Called whenever the build or skill points change.
    var onProgressionChange: ((ProgressionSnapshot) -> Void)?
    /// Called when the player gains one or more levels.
    var onLevelUp: ((Int) -> Void)?
    /// Called once when the run is over and the summary should be shown.
    var onRunEnded: ((RunSummary) -> Void)?
    /// Called when a find opens, or is answered.
    var onOfferChange: ((RelicOffer?) -> Void)?
    private var lastOffer: RelicOffer?
    private var lastHUDState = GameplayHUDState()
    private var lastProgression = ProgressionSnapshot()

    // MARK: Layers

    private let worldLayer = SKNode()
    private let groundDecalLayer: SKNode
    private let standingLayer: SKNode
    private let overlayLayer: SKNode

    // MARK: Renderers

    private let catalog: SpriteCatalog
    private let ground: WrappingGroundRenderer
    private let decorations: DecorationRenderer
    private let playerView: PlayerView
    private let enemyRenderer: EnemyRenderer
    private let allyRenderer: AllyRenderer
    private let projectileRenderer: ProjectileRenderer
    private let pickupRenderer: PickupRenderer
    private let dropRenderer: DropRenderer
    private let shrineRenderer: ShrineRenderer
    private let zoneRenderer: ZoneRenderer
    private let chargeLanes: ChargeLaneRenderer
    private let effects: EffectsRenderer
    private let feedback: CombatFeedback
    private let cameraController: CameraController
    private let atmosphere: AtmosphereRenderer
    private let hud = GameHUDNode()

    // MARK: Input

    private var joystick: JoystickModel
    private weak var joystickTouch: UITouch?
    private var safeInsets = ScreenInsets.zero

    // MARK: Developer tooling

    private var frameMeter = FrameRateMeter()
    private var simulationTimeAccumulator: TimeInterval = 0
    private var simulationFrames = 0
    private var performanceOverlay: PerformanceOverlayNode?
    private var seamOverlay: WrapSeamOverlayNode?

    // MARK: - Lifecycle

    init(run: RunConfiguration, dependencies: Dependencies) {
        self.dependencies = dependencies
        let tuning = dependencies.tuning
        let simulation = GameSimulation(run: run, tuning: tuning, legacy: dependencies.legacy,
                                        bonusRerolls: dependencies.bonusRerolls)
        self.simulation = simulation

        // Collaborators are built from locals: `self` cannot be read until
        // every stored property is set.
        let projection = IsometricProjection(tileWidth: tuning.projection.tileWidth,
                                             tileHeight: tuning.projection.tileHeight)
        self.projection = projection
        renderFrame = WrappedRenderFrame(world: simulation.world, focus: simulation.player.position)
        timestep = FixedTimestep(step: tuning.simulation.timestep,
                                 maxStepsPerFrame: tuning.simulation.maxStepsPerFrame)
        joystick = JoystickModel(radius: tuning.controls.joystickRadius,
                                 deadZone: tuning.controls.joystickDeadZone,
                                 followsThumb: tuning.controls.joystickFollowsThumb)

        let catalog = SpriteCatalog(preloading: SpriteCatalog.gameplaySprites, hero: dependencies.hero)
        self.catalog = catalog
        let standing = SKNode()
        let decals = SKNode()
        let overlays = SKNode()
        standingLayer = standing
        groundDecalLayer = decals
        overlayLayer = overlays

        let theme = simulation.realm.arena.theme
        ground = WrappingGroundRenderer(layout: simulation.arena, theme: theme, projection: projection)
        decorations = DecorationRenderer(placements: simulation.arena.decorations, world: simulation.world,
                                         projection: projection, catalog: catalog,
                                         standingLayer: standing, decalLayer: decals)
        let player = PlayerView(catalog: catalog, weaponSprite: simulation.weapon.spriteID, hand: dependencies.hero.build.hand)
        playerView = player
        // One world unit along a tile edge spans half a tile diagonal on screen.
        let pointsPerWorldUnit = tuning.projection.tileWidth / 2 * CGFloat(2).squareRoot()
        let camera = CameraController(tuning: tuning.camera, pointsPerWorldUnit: pointsPerWorldUnit)
        cameraController = camera
        atmosphere = AtmosphereRenderer(atmosphere: theme.atmosphere, catalog: catalog, worldLayer: overlays)

        let enemies = EnemyRenderer(catalog: catalog, projection: projection, layer: standing,
                                    pointsPerWorldUnit: pointsPerWorldUnit)
        enemyRenderer = enemies
        allyRenderer = AllyRenderer(catalog: catalog, projection: projection, layer: standing)
        projectileRenderer = ProjectileRenderer(catalog: catalog, projection: projection, layer: standing)
        pickupRenderer = PickupRenderer(catalog: catalog, projection: projection, layer: standing)
        dropRenderer = DropRenderer(catalog: catalog, projection: projection, layer: standing)
        shrineRenderer = ShrineRenderer(catalog: catalog, projection: projection, layer: standing)
        zoneRenderer = ZoneRenderer(catalog: catalog, projection: projection, pointsPerWorldUnit: pointsPerWorldUnit,
                                    layer: decals)
        chargeLanes = ChargeLaneRenderer(projection: projection, layer: decals)
        let effects = EffectsRenderer(catalog: catalog, projection: projection, pointsPerWorldUnit: pointsPerWorldUnit,
                                      standingLayer: standing, decalLayer: decals, overlayLayer: overlays)
        self.effects = effects
        feedback = CombatFeedback(effects: effects, enemies: enemies, player: player, camera: camera,
                                  projection: projection, audio: dependencies.audio, haptics: dependencies.haptics)
        feedback.levelUpRadius = tuning.progression.levelUpBurstRadius

        super.init(size: CGSize(width: 1, height: 1))
        scaleMode = .resizeFill
        backgroundColor = theme.atmosphere.background.uiColor
        buildSceneGraph()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("GameScene is created in code")
    }

    private func buildSceneGraph() {
        addChild(worldLayer)
        ground.node.zPosition = DepthSorting.Band.ground
        groundDecalLayer.zPosition = DepthSorting.Band.groundDecals
        standingLayer.zPosition = DepthSorting.Band.standing
        overlayLayer.zPosition = DepthSorting.Band.overlays
        worldLayer.addChild(ground.node)
        worldLayer.addChild(groundDecalLayer)
        worldLayer.addChild(standingLayer)
        worldLayer.addChild(overlayLayer)
        standingLayer.addChild(playerView)

        addChild(cameraController.camera)
        camera = cameraController.camera
        atmosphere.attach(to: cameraController.camera)
        cameraController.camera.addChild(hud)

        #if FATELOST_DEVTOOLS
        let overlay = PerformanceOverlayNode()
        overlay.isHidden = true
        hud.addChild(overlay)
        performanceOverlay = overlay

        let seams = WrapSeamOverlayNode()
        seams.isHidden = true
        overlayLayer.addChild(seams)
        seamOverlay = seams
        #endif

        let start = projection.toScreen(renderFrame.focusUnwrapped)
        cameraController.snap(to: start)
        ground.update(focusUnwrapped: renderFrame.focusUnwrapped, force: true)
    }

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = true
        view.ignoresSiblingOrder = true
        view.preferredFramesPerSecond = tuning.rendering.preferredFramesPerSecond
        safeInsets = ScreenInsets(view.safeAreaInsets)
        relayout()
        publishProgressionIfChanged(force: true)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        relayout()
    }

    /// Called by the hosting view when the notch/home-indicator insets change.
    func updateSafeArea(_ insets: UIEdgeInsets) {
        let converted = ScreenInsets(insets)
        guard converted != safeInsets else { return }
        safeInsets = converted
        relayout()
    }

    private func relayout() {
        // `hud` is created before super.init, but layout needs a real size.
        guard size.width > 1, size.height > 1 else { return }
        let layout = HUDLayout(screenSize: size, insets: safeInsets, tuning: tuning.controls)
        hud.apply(layout)
        joystick = JoystickModel(radius: layout.joystickRadius, deadZone: tuning.controls.joystickDeadZone,
                                 followsThumb: tuning.controls.joystickFollowsThumb)
        joystickTouch = nil
        hud.joystick.show(joystick, restPosition: layout.joystickRest)
        updateAbilityButtons()
        performanceOverlay?.position = layout.overlayOrigin + CGPoint(x: 0, y: -44 * layout.controlScale)

        cameraController.configureScale(forViewSize: size)
        atmosphere.layout(screenSize: size)
        feedback.layout(screenSize: size)
        decorations.update(frame: renderFrame, radius: visibleWorldRadius(), force: true)
        // Enemies arrive just past the corners of the screen, never in view.
        simulation.spawnRadius = max(tuning.spawning.spawnRadius, screenCornerWorldDistance() + 1.5)
    }

    // MARK: - Frame loop

    override func update(_ currentTime: TimeInterval) {
        guard let previous = lastUpdateTime else {
            lastUpdateTime = currentTime
            return
        }
        lastUpdateTime = currentTime
        // Clamp so a hitch (or returning from background) cannot produce a
        // giant step; the fixed timestep caps catch-up as well.
        let frameDelta = min(max(currentTime - previous, 0), 0.25)
        updateDeveloperTooling(frameDelta: frameDelta)

        guard !isGameplayPaused else { return }
        animationTime += frameDelta
        runDeveloperCommands()

        // Hit-stop holds the simulation for a beat; rendering carries on so
        // shake and flashes still play.
        hitStopRemaining = max(hitStopRemaining, feedback.consumeHitStop())
        var simulatedDelta = frameDelta * dependencies.developer.gameSpeed
        if hitStopRemaining > 0 {
            hitStopRemaining -= frameDelta
            simulatedDelta = 0
        }
        if simulation.isPlayerDefeated {
            simulatedDelta *= Timing.defeatTimeScale
        }

        simulation.cheats = SimulationCheats(godMode: dependencies.developer.godMode,
                                             spawningEnabled: dependencies.developer.spawningEnabled)
        let steps = timestep.advance(by: simulatedDelta)
        var intent = currentIntent()
        let started = CACurrentMediaTime()
        for _ in 0..<steps {
            // A find that has just opened holds the rest of the frame.
            if simulation.offer != nil { break }
            intent.abilityPresses = pendingAbilityPresses
            simulation.step(dt: timestep.step, intent: intent)
            // A press is used by the first step that sees it.
            pendingAbilityPresses = 0
        }
        recordSimulationTime(CACurrentMediaTime() - started)

        let lowHealth = simulation.player.health < simulation.player.maxHealth * Timing.lowHealthFraction
            && !simulation.isPlayerDefeated
        // Events are presented before renderers update, so a killed enemy's
        // view still exists to spawn its falling body from.
        let events = simulation.drainEvents()
        feedback.playerPosition = simulation.player.position
        feedback.playerSpriteID = simulation.activeForm?.sprite ?? .playerAdventurer
        feedback.present(events, lowHealth: lowHealth, frame: renderFrame, dt: CGFloat(frameDelta))

        render(frameDelta: CGFloat(frameDelta))
        publishHUDStateIfChanged()
        publishProgressionIfChanged()
        publishOfferIfChanged()
        reportLevelUps(in: events)
        deliverSummaryIfDue()
    }

    private func currentIntent() -> PlayerIntent {
        PlayerIntent(move: projection.worldDirection(fromScreen: joystick.output))
    }

    private func render(frameDelta: CGFloat) {
        let player = simulation.player
        renderFrame.moveFocus(toWrapped: player.position)

        let rebaseShift = renderFrame.rebaseIfNeeded(thresholdPeriods: tuning.rendering.rebaseThresholdPeriods)
        let rebased = rebaseShift != .zero
        if rebased {
            cameraController.shift(by: -projection.toScreen(rebaseShift))
        }

        let playerScreen = projection.toScreen(renderFrame.focusUnwrapped)
        playerView.position = playerScreen
        playerView.zPosition = DepthSorting.z(forScreenY: playerScreen.y)
        let screenVelocity = projection.toScreen(player.velocity)
        playerView.setForm(simulation.activeForm)
        playerView.apply(player, screenVelocity: screenVelocity, dt: frameDelta)

        cameraController.shakeEnabled = dependencies.settings.settings.cameraShakeEnabled
        let motion = screenVelocity.normalized * min(1, player.velocity.length / tuning.player.baseMoveSpeed)
        cameraController.update(target: playerScreen, motion: motion, dt: frameDelta)
        // The HUD rides on the camera; cancel shake so controls stay still.
        hud.position = -cameraController.shakeOffset / max(cameraController.camera.xScale, 0.0001)

        ground.update(focusUnwrapped: renderFrame.focusUnwrapped, force: rebased)
        decorations.update(frame: renderFrame, radius: visibleWorldRadius(), force: rebased)
        zoneRenderer.update(zones: simulation.combat.zones, frame: renderFrame, time: animationTime)
        chargeLanes.update(enemies: simulation.combat.enemies, playerRadius: tuning.combat.playerRadius,
                           frame: renderFrame, time: animationTime)
        pickupRenderer.update(orbs: simulation.combat.orbs, frame: renderFrame, time: animationTime)
        dropRenderer.update(drops: simulation.combat.drops, frame: renderFrame, time: animationTime)
        shrineRenderer.update(shrines: simulation.combat.shrines, playerPosition: simulation.player.position,
                              frame: renderFrame, time: animationTime)
        updateBeacons()
        playerView.setWeapon(simulation.weapon.spriteID)
        enemyRenderer.update(enemies: simulation.enemies, frame: renderFrame, time: animationTime, dt: frameDelta,
                             showHitboxes: dependencies.developer.showHitboxes)
        allyRenderer.update(allies: simulation.combat.allies, frame: renderFrame, time: animationTime, dt: frameDelta)
        projectileRenderer.update(projectiles: simulation.projectiles, frame: renderFrame)
        effects.update(frame: renderFrame, dt: frameDelta)

        if let layout = hud.layout {
            hud.joystick.show(joystick, restPosition: layout.joystickRest)
        }
        updateAbilityButtons()
    }

    private func updateAbilityButtons() {
        var displays: [AbilitySlotDisplay] = []
        for slot in 0..<AbilitySlots.count {
            guard let id = simulation.abilitySlots[slot], let ability = SkillCatalog.ability(id),
                  let cooldown = simulation.cooldown(forSlot: slot) else {
                displays.append(.empty)
                continue
            }
            if cooldown.remaining > 0.01, cooldown.total > 0 {
                let progress = CGFloat(1 - cooldown.remaining / cooldown.total)
                displays.append(.coolingDown(symbol: ability.symbol, progress: progress,
                                             secondsRemaining: cooldown.remaining))
            } else {
                displays.append(.ready(symbol: ability.symbol))
            }
        }
        hud.showAbilities(displays)
    }

    /// World-unit radius around the focus that can appear on screen, plus a
    /// margin for tall objects whose base is just off-screen.
    private func visibleWorldRadius() -> CGFloat {
        let halfDiagonal = (size.width * size.width + size.height * size.height).squareRoot() / 2
        let scenePoints = halfDiagonal * cameraController.camera.xScale
        // The shortest on-screen world unit is vertical: √2 / tileHeight units per point.
        let worldPerPoint = CGFloat(2).squareRoot() / projection.tileHeight
        return scenePoints * worldPerPoint + tuning.rendering.decorationMargin
    }

    /// World distance from the screen centre to its farthest corner.
    private func screenCornerWorldDistance() -> CGFloat {
        let scale = cameraController.camera.xScale
        let halfWidth = size.width / 2 * scale
        let halfHeight = size.height / 2 * scale
        let a = projection.toWorld(CGPoint(x: halfWidth, y: halfHeight)).length
        let b = projection.toWorld(CGPoint(x: halfWidth, y: -halfHeight)).length
        return max(a, b)
    }

    // MARK: - Publishing

    private func publishHUDStateIfChanged() {
        let player = simulation.player
        let progression = simulation.progression
        let fraction = progression.required > 0 ? Double(progression.experience) / Double(progression.required) : 0
        let wave = simulation.wave
        let state = GameplayHUDState(health: player.health, maxHealth: player.maxHealth, barrier: player.barrier,
                                     elapsedSeconds: Int(simulation.elapsed), wave: wave.index,
                                     level: progression.level,
                                     experienceFraction: min(1, fraction), unspentPoints: progression.unspentPoints,
                                     kills: simulation.stats.kills, allyCount: simulation.allies.count,
                                     summonsDismissed: simulation.areSummonsDismissed,
                                     hasSummons: simulation.hasSummons,
                                     bossTitle: wave.isBossActive ? wave.bossTitle : nil,
                                     bossHealthFraction: wave.bossHealthFraction,
                                     curseSeconds: Int(simulation.curseRemaining.rounded(.up)))
        guard state != lastHUDState else { return }
        lastHUDState = state
        onHUDStateChange?(state)
    }

    private func publishProgressionIfChanged(force: Bool = false) {
        let progression = simulation.progression
        guard force
            || progression.level != lastProgression.level
            || progression.unspentPoints != lastProgression.unspentPoints
            || simulation.buildVersion != lastProgression.buildVersion
            || simulation.abilitySlots != lastProgression.abilitySlots else { return }
        let snapshot = ProgressionSnapshot(level: progression.level, unspentPoints: progression.unspentPoints,
                                           earnedPoints: progression.earnedPoints, allocation: simulation.allocation,
                                           abilitySlots: simulation.abilitySlots, buildVersion: simulation.buildVersion,
                                           relics: simulation.relics)
        lastProgression = snapshot
        onProgressionChange?(snapshot)
    }

    private func reportLevelUps(in events: [CombatEvent]) {
        var newest: Int?
        for event in events {
            if case .levelUp(let level, _) = event {
                newest = level
            }
        }
        if let newest {
            onLevelUp?(newest)
        }
    }

    private func deliverSummaryIfDue() {
        guard !summaryDelivered else { return }
        // Taking the realm ends the run as surely as falling does.
        if simulation.isRealmConquered {
            deliverSummary(outcome: .conquered, seconds: Int(simulation.elapsed))
            return
        }
        guard let sinceDefeat = simulation.timeSinceDefeat,
              sinceDefeat >= Timing.defeatSummaryDelay * Timing.defeatTimeScale else { return }
        deliverSummary(outcome: .defeated, seconds: Int(simulation.elapsed - sinceDefeat))
    }

    private func deliverSummary(outcome: RunSummary.Outcome, seconds: Int) {
        summaryDelivered = true
        resetInput()
        onRunEnded?(RunSummary(realm: simulation.run.realmID, weapon: simulation.run.starterWeaponID,
                               secondsSurvived: seconds, stats: simulation.stats,
                               level: simulation.progression.level, allocation: simulation.allocation,
                               outcome: outcome, wave: simulation.wave.index, relics: simulation.relics))
    }

    // MARK: - Beacons

    /// Points at chests and shrines that are off the edge of the screen. A
    /// find is worth crossing a fight for, but only if you can tell where it is.
    private func updateBeacons() {
        guard let layout = hud.layout else { return }
        let scale = max(cameraController.camera.xScale, 0.0001)
        let here = projection.toScreen(renderFrame.unwrapped(simulation.player.position))
        var marks: [BeaconMark] = []
        for drop in simulation.combat.drops {
            guard case .chest(let tier) = drop.kind else { continue }
            let there = projection.toScreen(renderFrame.unwrapped(drop.position))
            marks.append(BeaconMark(id: drop.id, offset: (there - here) / scale, color: Self.beaconColor(tier)))
        }
        for shrine in simulation.combat.shrines {
            let there = projection.toScreen(renderFrame.unwrapped(shrine.position))
            marks.append(BeaconMark(id: shrine.id, offset: (there - here) / scale,
                                    color: ShrineRenderer.tint(for: shrine.kind)))
        }
        marks.sort { $0.offset.lengthSquared < $1.offset.lengthSquared }
        hud.showBeacons(Array(marks.prefix(4)), screenSize: layout.screenSize, time: animationTime)
    }

    private static func beaconColor(_ tier: LootTier) -> UIColor {
        switch tier {
        case .cache: return ItemRarity.common.color.uiColor
        case .chest: return ItemRarity.rare.color.uiColor
        case .hoard: return ItemRarity.legendary.color.uiColor
        }
    }

    // MARK: - Finds

    /// The find waiting to be answered, if any.
    var currentOffer: RelicOffer? { simulation.offer }

    private func publishOfferIfChanged() {
        guard simulation.offer != lastOffer else { return }
        lastOffer = simulation.offer
        onOfferChange?(lastOffer)
    }

    /// Takes one of the cards on offer.
    @discardableResult
    func chooseRelic(at index: Int) -> Bool {
        let accepted = simulation.chooseRelic(at: index)
        publishProgressionIfChanged(force: true)
        publishHUDStateIfChanged()
        publishOfferIfChanged()
        return accepted
    }

    /// Takes the weapon on offer.
    @discardableResult
    func chooseWeapon() -> Bool {
        let accepted = simulation.chooseWeapon()
        publishHUDStateIfChanged()
        publishOfferIfChanged()
        return accepted
    }

    /// Spends the offer's reroll.
    @discardableResult
    func rerollOffer() -> Bool {
        let accepted = simulation.rerollOffer()
        publishOfferIfChanged()
        return accepted
    }

    // MARK: - Build

    /// Commits a skill draft. Returns false if the simulation rejected it.
    @discardableResult
    func commitBuild(_ draft: SkillAllocation, slots: [AbilityID?]) -> Bool {
        let accepted = simulation.commit(draft, slots: slots)
        publishProgressionIfChanged(force: true)
        publishHUDStateIfChanged()
        updateAbilityButtons()
        return accepted
    }

    /// Sends the player's summons away, or calls them back.
    func toggleSummons() {
        simulation.toggleSummonsDismissed()
        publishHUDStateIfChanged()
    }

    func equipAbilities(_ slots: [AbilityID?]) {
        simulation.equip(slots)
        publishProgressionIfChanged(force: true)
        updateAbilityButtons()
    }

    // MARK: - Touch input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let layout = hud.layout else { return }
        for touch in touches {
            let point = touch.location(in: hud)
            if let slot = layout.abilitySlot(at: point) {
                pendingAbilityPresses |= 1 << UInt8(slot)
                hud.pulseAbility(slot)
                continue
            }
            if joystickTouch == nil, point.x < layout.joystickZoneMaxX {
                joystickTouch = touch
                joystick.begin(at: point)
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches where touch === joystickTouch {
            joystick.move(to: touch.location(in: hud))
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        releaseJoystick(ifAmong: touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        releaseJoystick(ifAmong: touches)
    }

    private func releaseJoystick(ifAmong touches: Set<UITouch>) {
        guard let active = joystickTouch, touches.contains(active) else { return }
        joystickTouch = nil
        joystick.end()
    }

    /// Drops any held input, e.g. when the game is paused mid-drag.
    func resetInput() {
        joystickTouch = nil
        joystick.end()
        pendingAbilityPresses = 0
    }

    // MARK: - Developer tooling

    private func runDeveloperCommands() {
        for command in dependencies.developer.takeCommands() {
            switch command {
            case .spawnEnemies(let count):
                simulation.spawnEnemies(count)
            case .defeatAllEnemies:
                simulation.defeatAllEnemies()
            case .restoreHealth:
                simulation.restorePlayerHealth()
            case .shakeCamera:
                cameraController.addTrauma(0.7)
            case .grantLevels(let count):
                simulation.grantLevels(count)
            case .resetSkills:
                simulation.resetSkills()
            }
        }
    }

    private func recordSimulationTime(_ seconds: TimeInterval) {
        simulationTimeAccumulator += seconds
        simulationFrames += 1
    }

    private func updateDeveloperTooling(frameDelta: TimeInterval) {
        let developer = dependencies.developer
        let fpsUpdated = frameMeter.record(frameDelta: frameDelta)

        if let seamOverlay {
            seamOverlay.isHidden = !developer.showWrapSeams
            if developer.showWrapSeams {
                seamOverlay.update(frame: renderFrame, projection: projection)
            }
        }

        guard let overlay = performanceOverlay else { return }
        overlay.isHidden = !developer.showPerformanceOverlay
        guard developer.showPerformanceOverlay, fpsUpdated else { return }

        var snapshot = PerformanceSnapshot()
        snapshot.framesPerSecond = frameMeter.framesPerSecond
        snapshot.nodeCount = PerformanceOverlayNode.countNodes(in: self)
        snapshot.playerPosition = simulation.player.position
        snapshot.activeDecorations = decorations.activeCount
        snapshot.enemyCount = simulation.enemies.count
        snapshot.projectileCount = simulation.projectiles.count
        snapshot.pickupCount = simulation.combat.orbs.count
        snapshot.playerLevel = simulation.progression.level
        snapshot.activeEffects = effects.activeCount + zoneRenderer.activeCount + chargeLanes.activeCount + allyRenderer.activeCount
        snapshot.spawnRate = simulation.currentSpawnRate
        if simulationFrames > 0 {
            snapshot.simulationMilliseconds = simulationTimeAccumulator / Double(simulationFrames) * 1000
        }
        simulationTimeAccumulator = 0
        simulationFrames = 0
        overlay.show(snapshot)
    }
}

private extension ScreenInsets {
    init(_ insets: UIEdgeInsets) {
        self.init(top: insets.top, left: insets.left, bottom: insets.bottom, right: insets.right)
    }
}
