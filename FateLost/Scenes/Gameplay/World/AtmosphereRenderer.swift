import SpriteKit

/// Screen-space mood: an edge vignette and drifting ambient particles.
///
/// The vignette is parented to the camera so it frames the screen. The
/// particle emitter follows the camera too, but emits into the world layer,
/// so ash and embers stay put as the player walks through them.
@MainActor
final class AtmosphereRenderer {
    let vignette: SKSpriteNode
    private let emitter: SKEmitterNode?

    init(atmosphere: Atmosphere, catalog: SpriteCatalog, worldLayer: SKNode) {
        vignette = SKSpriteNode(texture: SKTexture(image: PlaceholderArt.vignette(color: atmosphere.vignette)))
        vignette.zPosition = DepthSorting.Band.overlays

        emitter = Self.makeEmitter(atmosphere, catalog: catalog)
        if let emitter {
            emitter.targetNode = worldLayer
            emitter.zPosition = DepthSorting.Band.overlays - 1
        }
    }

    /// Attaches both effects to the camera.
    func attach(to camera: SKCameraNode) {
        camera.addChild(vignette)
        if let emitter {
            camera.addChild(emitter)
            // Pre-fill the sky so the first frames are not empty.
            emitter.advanceSimulationTime(6)
        }
    }

    /// Sizes the effects to the visible screen (in camera-local points).
    func layout(screenSize: CGSize) {
        vignette.size = CGSize(width: screenSize.width * 1.05, height: screenSize.height * 1.05)
        if let emitter {
            emitter.position = CGPoint(x: 0, y: screenSize.height * 0.55)
            emitter.particlePositionRange = CGVector(dx: screenSize.width * 1.6, dy: screenSize.height * 0.4)
        }
    }

    private static func makeEmitter(_ atmosphere: Atmosphere, catalog: SpriteCatalog) -> SKEmitterNode? {
        guard atmosphere.particles != .none, let texture = catalog.texture(.fxAshFlake) else { return nil }
        let emitter = SKEmitterNode()
        emitter.particleTexture = texture
        emitter.particleBirthRate = atmosphere.particleRate
        emitter.particleColor = atmosphere.particleColor.uiColor
        emitter.particleColorBlendFactor = 1
        emitter.particleAlpha = CGFloat(atmosphere.particleColor.alpha)
        emitter.particleAlphaRange = 0.3
        emitter.particleLifetime = 9
        emitter.particleLifetimeRange = 3
        emitter.particleScale = 0.6
        emitter.particleScaleRange = 0.4

        switch atmosphere.particles {
        case .none:
            return nil
        case .ash, .snow:
            emitter.emissionAngle = -.pi / 2 - 0.3
            emitter.emissionAngleRange = 0.5
            emitter.particleSpeed = atmosphere.particles == .snow ? 55 : 28
            emitter.particleSpeedRange = 15
            emitter.xAcceleration = 6
            emitter.particleRotationSpeed = 1
            emitter.particleAlphaSpeed = -0.05
        case .embers:
            emitter.emissionAngle = .pi / 2
            emitter.emissionAngleRange = 0.8
            emitter.particleSpeed = 30
            emitter.particleSpeedRange = 20
            emitter.yAcceleration = 8
            emitter.particleBlendMode = .add
            emitter.particleAlphaSpeed = -0.12
        case .spores, .motes:
            emitter.emissionAngleRange = .pi * 2
            emitter.particleSpeed = 10
            emitter.particleSpeedRange = 8
            emitter.particleBlendMode = .add
            emitter.particleAlphaSequence = SKKeyframeSequence(
                keyframeValues: [0, atmosphere.particleColor.alpha, 0],
                times: [0, 0.5, 1]
            )
        }
        return emitter
    }
}
