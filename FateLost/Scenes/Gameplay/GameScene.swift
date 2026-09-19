import SpriteKit

/// Informational HUD values handed to SwiftUI. Published only on change.
struct GameplayHUDState: Equatable {
    var health: Double = 0
    var maxHealth: Double = 1
    var elapsedSeconds: Int = 0
    var wave: Int = 1
    var level: Int = 1
}

/// The gameplay scene.
///
/// A coordinator, not a god object: it owns no game rules. Each frame it
/// turns touches into a `PlayerIntent`, advances `GameSimulation` in fixed
/// steps, then hands the resulting state to focused renderers (ground,
/// decorations, player, camera, HUD). New gameplay belongs in simulation
/// systems; new visuals belong in renderers.
final class GameScene: SKScene {
    struct Dependencies {
        let tuning: GameTuning
        let settings: SettingsStore
        let developer: DeveloperOptions
    }

    // MARK: State

    private(set) var simulation: GameSimulation
    private let dependencies: Dependencies
    private var tuning: GameTuning { dependencies.tuning }
    private let projection: IsometricProjection
    private var renderFrame: WrappedRenderFrame
    private var timestep: FixedTimestep
    private var lastUpdateTime: TimeInterval?

    /// Freezes simulation while leaving rendering alive (pause menu, level-up).
    var isGameplayPaused = false {
        didSet {
            lastUpdateTime = nil
            timestep.reset()
        }
    }

    /// Called on the main thread whenever HUD-relevant values change.
    var onHUDStateChange: ((GameplayHUDState) -> Void)?
    private var lastHUDState = GameplayHUDState()

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
    private let cameraController: CameraController
    private let atmosphere: AtmosphereRenderer
    private let hud = GameHUDNode()

    // MARK: Input

    private var joystick: JoystickModel
    private weak var joystickTouch: UITouch?
    private var safeInsets = ScreenInsets.zero

    // MARK: Developer tooling

    private var frameMeter = FrameRateMeter()
    private var performanceOverlay: PerformanceOverlayNode?
    private var seamOverlay: WrapSeamOverlayNode?
    private var lastShakeTestCounter: Int

    // MARK: - Lifecycle

    init(run: RunConfiguration, dependencies: Dependencies) {
        self.dependencies = dependencies
        let tuning = dependencies.tuning
        let simulation = GameSimulation(run: run, tuning: tuning)
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

        let catalog = SpriteCatalog(preloading: SpriteCatalog.gameplaySprites)
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
        playerView = PlayerView(catalog: catalog, weaponSprite: simulation.weapon.spriteID)
        // One world unit along a tile edge spans half a tile diagonal on screen.
        let pointsPerWorldUnit = tuning.projection.tileWidth / 2 * CGFloat(2).squareRoot()
        cameraController = CameraController(tuning: tuning.camera, pointsPerWorldUnit: pointsPerWorldUnit)
        atmosphere = AtmosphereRenderer(atmosphere: theme.atmosphere, catalog: catalog, worldLayer: overlays)
        lastShakeTestCounter = dependencies.developer.shakeTestCounter

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
        hud.showAbilities([])
        performanceOverlay?.position = layout.overlayOrigin + CGPoint(x: 0, y: -44 * layout.controlScale)

        cameraController.configureScale(forViewSize: size)
        atmosphere.layout(screenSize: size)
        decorations.update(frame: renderFrame, radius: visibleWorldRadius(), force: true)
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

        let simulatedDelta = frameDelta * dependencies.developer.gameSpeed
        let steps = timestep.advance(by: simulatedDelta)
        let intent = currentIntent()
        for _ in 0..<steps {
            simulation.step(dt: timestep.step, intent: intent)
        }

        render(frameDelta: CGFloat(frameDelta))
        publishHUDStateIfChanged()
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
        playerView.apply(player, screenVelocity: screenVelocity)

        cameraController.shakeEnabled = dependencies.settings.settings.cameraShakeEnabled
        let motion = screenVelocity.normalized * min(1, player.velocity.length / tuning.player.baseMoveSpeed)
        cameraController.update(target: playerScreen, motion: motion, dt: frameDelta)
        // The HUD rides on the camera; cancel shake so controls stay still.
        hud.position = -cameraController.shakeOffset / max(cameraController.camera.xScale, 0.0001)

        ground.update(focusUnwrapped: renderFrame.focusUnwrapped, force: rebased)
        decorations.update(frame: renderFrame, radius: visibleWorldRadius(), force: rebased)

        if let layout = hud.layout {
            hud.joystick.show(joystick, restPosition: layout.joystickRest)
        }
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

    private func publishHUDStateIfChanged() {
        let player = simulation.player
        let state = GameplayHUDState(health: player.health, maxHealth: player.maxHealth,
                                     elapsedSeconds: Int(simulation.elapsed), wave: 1, level: 1)
        guard state != lastHUDState else { return }
        lastHUDState = state
        onHUDStateChange?(state)
    }

    // MARK: - Touch input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let layout = hud.layout else { return }
        for touch in touches {
            let point = touch.location(in: hud)
            if layout.abilitySlot(at: point) != nil {
                // Abilities arrive with the skill system in Phase 3.
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
    }

    // MARK: - Developer tooling

    private func updateDeveloperTooling(frameDelta: TimeInterval) {
        let developer = dependencies.developer
        let fpsUpdated = frameMeter.record(frameDelta: frameDelta)

        if developer.shakeTestCounter != lastShakeTestCounter {
            lastShakeTestCounter = developer.shakeTestCounter
            cameraController.addTrauma(0.7)
        }

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
        overlay.show(snapshot)
    }
}

private extension ScreenInsets {
    init(_ insets: UIEdgeInsets) {
        self.init(top: insets.top, left: insets.left, bottom: insets.bottom, right: insets.right)
    }
}
