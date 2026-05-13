package;

import openfl.display.Sprite;
import openfl.events.MouseEvent;
import openfl.events.KeyboardEvent;
import openfl.events.Event;
import openfl.Lib;
import openfl.ui.Keyboard;
import openfl.geom.Point;
import openfl.display.Shape;
import interfaces.IGameController;
import config.GameConfig;
import config.SettingsConfig;
import config.SettingsTimePresets;
import config.CustomLayoutsStore;
import config.PieceCatalog;
import ui.UIPanel;
import ui.UITabBar;
import ui.GameClockView;
import ui.GameClockView.ClockVisualStyle;
import ui.GameEndOverlay;
import ui.BoardViewPort;
import ui.WindowFullscreen;
import utils.MouseHandler;
import utils.PieceCursor;
import utils.IntBounds;
import utils.ClockFormat;
import managers.SoundManager;
import managers.UCIManager;
import managers.EnginePlayer;
import ui.SettingsTab;
import ui.LayoutMakerTab;
import ui.EnginesTab;
import ui.MoveHistoryPanel;
import controllers.GameController;
import ui.BoardAnnotations;
import game.EngineMoveHandler;
import game.EngineVariantSync;
import game.HistoryReplayController;
import game.GameEndCopy;
import haxe.Timer;

/**
 * Main entry point for the chess game
 */
class Main extends Sprite {
    private var tileSize:Int;
    private var controller:IGameController;
    private var boardRenderer:interfaces.IBoardRenderer;
    private var pieceRenderer:interfaces.IPieceRenderer;

    // Engine player to handle engine moves
    private var enginePlayer:EnginePlayer;
    
    private var boardContainer:Sprite;
    private var boardViewPort:BoardViewPort;
    /** Coordinate space for board hit-tests (zoom/pan transform). */
    private var boardWorld:Sprite;
    /** Visible game board viewport size (for clocks, overlay, move list height). */
    private var gameBoardViewW:Int = 800;
    private var gameBoardViewH:Int = 600;
    private var settingsContainer:Sprite;
    private var uiPanel:UIPanel;
    private var panelPadding:Int = 20;
    private var historyGap:Int = 12;
    private var moveHistoryPanel:MoveHistoryPanel;
    private var clockView:GameClockView;
    private var boardAnnotations:BoardAnnotations;
    private var currentTab:Int = 0; // 0 = Game, 1 = Settings, 2 = Engines, 3 = Layout maker
    private var mouseHandler:MouseHandler;
    private var settingsTab:SettingsTab;
    private var enginesContainer:Sprite;
    private var enginesTab:EnginesTab;
    private var layoutMakerContainer:Sprite;
    private var layoutMakerTab:LayoutMakerTab;
    private var historyReplay:HistoryReplayController;
    private var historyLeftHeld:Bool = false;
    private var historyRightHeld:Bool = false;
    /** Min seconds between steps while an arrow is held (keydown still moves once immediately). */
    private static inline var HISTORY_HOLD_STEP_INTERVAL_SEC:Float = 0.10;
    private var lastHistoryHoldStepStamp:Float = -999.0;
    private var engineVariantSync:EngineVariantSync;
    private var engineMoveHandler:EngineMoveHandler;
    private var engineIntegrationInit:Bool = false;
    private var engineSessionInitialized:Bool = false;
    private var initialClockMs:Int = 0;
    private var whiteClockMs:Float = 0;
    private var blackClockMs:Float = 0;
    private var lastClockStamp:Float = 0.0;
    private var timeoutWinner:String = "";
    private var clocksStarted:Bool = false;
    /** Half-moves for which clock increment has already been applied (Fischer). */
    private var clockHistoryLenBaseline:Int = 0;
    private var gameEndOverlay:GameEndOverlay;
    private var gameEndOverlayActiveKey:String = "";
    private var gameEndOverlayDismissedKey:String = "";

    private var rtAnnotating:Bool = false;
    private var rtStartCol:Int = 0;
    private var rtStartRow:Int = 0;
    private var rtStartStageX:Float = 0;
    private var rtStartStageY:Float = 0;
    private var rtHoldPending:Bool = false;
    private var rtHoldActivated:Bool = false;
    private var rtHoldTimer:haxe.Timer;

    private var summonContextMenu:Sprite;
    private var summonPieceList:Sprite;
    private var summonMenuTile:Null<{col:Int, row:Int}>;
    
    public function new() {
        super();
        
        tileSize = GameConfig.DEFAULT_TILE_SIZE;
        
        stage.color = 0xFF1A1A1A;
        
        // Load saved settings
        SettingsConfig.load();
        CustomLayoutsStore.instance.load();
        SettingsConfig.revalidateBoardLayoutAfterCustomLayoutsLoaded();

        // Initialize game components
        controller = new controllers.GameController();
        boardRenderer = new renderers.BoardRenderer(tileSize);
        pieceRenderer = new renderers.PieceRenderer(tileSize);
        
        // Initialize sound manager
        SoundManager.getInstance();

        // Initial setup
        setupUI();

        PieceCursor.init(stage);
        mouseHandler = new MouseHandler(stage, controller, boardRenderer, pieceRenderer, boardWorld, boardViewPort, tileSize);
        mouseHandler.setOnMoveComplete(refreshMoveHistory);
        mouseHandler.setOnSelectionChange(refreshMoveHistory);
        mouseHandler.setOnEngineTurn(checkEngineTurn);
        mouseHandler.setHumanMayMoveCheck(function() {
            return (enginePlayer == null || enginePlayer.humanMayMovePieces(controller))
                && !controller.isBrowsingHistory()
                && !isTimeoutActive();
        });
        mouseHandler.setOnBoardLeftTap(function(col:Int, row:Int) {
            if (boardAnnotations != null)
                boardAnnotations.removeArrowsTouchingSquare(col, row);
        });

        historyReplay = new HistoryReplayController(mouseHandler, controller, boardRenderer, pieceRenderer, boardAnnotations);
        historyReplay.onAfterFinishHistory = function() {
            refreshMoveHistory();
            checkEngineTurn();
            refreshClockLabels();
        };

        engineVariantSync = new EngineVariantSync();
        engineMoveHandler = new EngineMoveHandler(mouseHandler, controller, boardRenderer, pieceRenderer);
        engineMoveHandler.onAfterAnim = function() {
            refreshMoveHistory();
            checkEngineTurn();
        };

        initEngineIntegrationOnce();

        stage.addEventListener(MouseEvent.RIGHT_MOUSE_DOWN, onStageRightMouseDown);
        stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
        stage.addEventListener(KeyboardEvent.KEY_UP, onKeyUp);

        // Register promotion completion callback
        controller.setOnPromotionCompleted(onPromotionCompleted);
        
        // Setup window event handling
        stage.addEventListener(Event.RESIZE, onResize);
        stage.addEventListener(Event.ENTER_FRAME, onEnterFrame);
    }
    
    private function setupUI(?preserveClockState:Bool = false):Void {
        // Remove old UI if it exists
        if (uiPanel != null && contains(uiPanel)) removeChild(uiPanel);
        if (boardContainer != null && contains(boardContainer)) removeChild(boardContainer);
        if (settingsContainer != null && contains(settingsContainer)) removeChild(settingsContainer);
        if (enginesContainer != null && contains(enginesContainer)) removeChild(enginesContainer);
        if (layoutMakerContainer != null && contains(layoutMakerContainer)) removeChild(layoutMakerContainer);
        if (moveHistoryPanel != null && contains(moveHistoryPanel)) removeChild(moveHistoryPanel);

        var stg = stage != null ? stage : Lib.current.stage;
        var sw = stg != null ? Std.int(stg.stageWidth) : 860;
        var sh = stg != null ? Std.int(stg.stageHeight) : 804;
        if (sw < 480)
            sw = 480;
        if (sh < 360)
            sh = 360;

        uiPanel = new UIPanel(sw, sh, 0x1A1A1A, 0x555555, 2, panelPadding, true);
        uiPanel.x = 0;
        uiPanel.y = 0;
        addChild(uiPanel);

        var tabBar = uiPanel.getTabBar();
        if (currentTab >= 4)
            currentTab = 0;
        tabBar.addTab("Game");
        tabBar.addTab("Settings");
        tabBar.addTab("Engines");
        tabBar.addTab("Layouts");
        tabBar.setOnTabChange(onTabChange);
        tabBar.setActiveTab(currentTab);
        tabBar.setStretchWidth(uiPanel.getContentWidth());

        var innerW = uiPanel.getContentWidth();
        var innerH = uiPanel.getContentHeight();
        GameConfig.syncFromBoard(controller.getBoardData());
        var layoutTimed = SettingsTimePresets.presetToMs(SettingsConfig.timeControlPreset) > 0;
        var gameTopInset = layoutTimed ? GameClockView.verticalInsetTimed() : 0;
        var gameBottomInset = gameTopInset;
        var histW = IntBounds.clampi(Std.int(innerW * 0.20), 120, 320);
        var availBoardW = innerW - historyGap - histW;
        var availBoardH = innerH - gameTopInset - gameBottomInset;
        gameBoardViewW = Std.int(availBoardW);
        gameBoardViewH = Std.int(availBoardH);
        var rawTile = Std.int(Math.min(availBoardW / GameConfig.boardCols, availBoardH / GameConfig.boardRows));
        tileSize = IntBounds.clampi(rawTile, 24, GameConfig.MAX_TILE_SIZE);

        var boardPixelW = tileSize * GameConfig.boardCols;
        var boardPixelH = tileSize * GameConfig.boardRows;
        var contentLeft = uiPanel.x + uiPanel.getContentX();

        boardRenderer.setTileSize(tileSize);
        pieceRenderer.setTileSize(tileSize);

        // Create board container flush left; move list is aligned to the right of the content area
        boardContainer = new Sprite();
        boardContainer.x = contentLeft;
        boardContainer.y = uiPanel.y + uiPanel.getContentY() + gameTopInset;
        addChild(boardContainer);

        boardViewPort = new BoardViewPort(gameBoardViewW, gameBoardViewH);
        boardContainer.addChild(boardViewPort);
        boardWorld = boardViewPort.world;

        // Add board and pieces inside zoom/pan world
        if (!boardWorld.contains(cast boardRenderer)) {
            boardWorld.addChild(cast boardRenderer);
        }
        boardAnnotations = new BoardAnnotations(tileSize);
        if (!boardWorld.contains(boardAnnotations.belowPieces)) {
            boardWorld.addChild(boardAnnotations.belowPieces);
        }
        if (!boardWorld.contains(cast pieceRenderer)) {
            boardWorld.addChild(cast pieceRenderer);
        }
        if (!boardWorld.contains(boardAnnotations.abovePieces)) {
            boardWorld.addChild(boardAnnotations.abovePieces);
        }
        boardViewPort.resetView();
        if (historyReplay != null)
            historyReplay.setBoardAnnotations(boardAnnotations);

        moveHistoryPanel = new MoveHistoryPanel(histW, Std.int(availBoardH));
        moveHistoryPanel.x = contentLeft + innerW - histW;
        moveHistoryPanel.y = boardContainer.y;
        addChild(moveHistoryPanel);

        // Create settings container
        settingsContainer = new Sprite();
        settingsContainer.x = uiPanel.x + uiPanel.getContentX();
        settingsContainer.y = uiPanel.y + uiPanel.getContentY();
        addChild(settingsContainer);
        
        settingsTab = new SettingsTab(Std.int(innerW), Std.int(innerH));
        settingsTab.onResetBoard = function() {
            cast(controller, GameController).resetBoardToClassic();
            resetClocksForPreset();
            setupUI(true);
            var uci = UCIManager.getInstance();
            if (uci.isEngineReady()) {
                uci.stopCalculation();
                syncEngineVariantForCurrentBoard();
                uci.setPosition(controller.getEngineFEN());
            }
            boardRenderer.setCheckHighlights(controller.getCheckedRoyals());
            boardRenderer.render(controller.getSelectedTile(), null, null, controller.getLastMoveHighlightFrom(), controller.getLastMoveHighlightTo());
            pieceRenderer.render(controller.getBoardData());
            boardAnnotations.clearAll();
            refreshMoveHistory();
            checkEngineTurn();
        };
        settingsTab.onBoardLayoutApply = function() {
            controller.applySavedBoardLayout();
            resetClocksForPreset();
            setupUI(true);
            var uci = UCIManager.getInstance();
            if (uci.isEngineReady()) {
                uci.stopCalculation();
                syncEngineVariantForCurrentBoard();
                uci.setPosition(controller.getEngineFEN());
            }
            boardRenderer.setCheckHighlights(controller.getCheckedRoyals());
            boardRenderer.render(controller.getSelectedTile(), null, null, controller.getLastMoveHighlightFrom(), controller.getLastMoveHighlightTo());
            pieceRenderer.render(controller.getBoardData());
            boardAnnotations.clearAll();
            refreshMoveHistory();
            checkEngineTurn();
        };
        settingsTab.onTimeControlChanged = function() {
            cast(controller, GameController).resetBoardToClassic();
            setupUI();
            checkEngineTurn();
        };
        settingsTab.onFullscreenModeChange = applyFullscreenFromConfig;
        settingsContainer.addChild(settingsTab);
        if (settingsTab != null)
            settingsTab.syncInputsFromConfig();

        enginesContainer = new Sprite();
        enginesContainer.x = uiPanel.x + uiPanel.getContentX();
        enginesContainer.y = uiPanel.y + uiPanel.getContentY();
        addChild(enginesContainer);
        enginesTab = new EnginesTab(Std.int(innerW), Std.int(innerH));
        enginesContainer.addChild(enginesTab);
        enginesTab.syncInputsFromConfig();

        layoutMakerContainer = new Sprite();
        layoutMakerContainer.x = uiPanel.x + uiPanel.getContentX();
        layoutMakerContainer.y = uiPanel.y + uiPanel.getContentY();
        addChild(layoutMakerContainer);
        var layoutTabFirstBuild = layoutMakerTab == null;
        if (layoutTabFirstBuild) {
            layoutMakerTab = new LayoutMakerTab(Std.int(innerW), Std.int(innerH));
            layoutMakerTab.onLayoutsChanged = function() {
                if (settingsTab != null)
                    settingsTab.syncInputsFromConfig();
            };
        } else {
            layoutMakerTab.setContentSize(Std.int(innerW), Std.int(innerH));
        }
        layoutMakerContainer.addChild(layoutMakerTab);
        if (layoutTabFirstBuild)
            layoutMakerTab.refreshDropdownFromSettings();

        if (mouseHandler != null) {
            mouseHandler.setBoardContainer(boardWorld);
            mouseHandler.setBoardViewPort(boardViewPort);
            mouseHandler.setTileSize(tileSize);
        }

        // Initial render (spawn-in only here — not on every selection / re-render)
        boardRenderer.render(null, null, null, controller.getLastMoveHighlightFrom(), controller.getLastMoveHighlightTo());
        pieceRenderer.render(controller.getBoardData(), true);
        boardAnnotations.redraw();
        if (!preserveClockState)
            resetClocksForPreset();
        else {
            syncGameClockLayout();
            refreshClockLabels();
        }
        refreshMoveHistory();

        // Show correct tab
        updateTabVisibility();

        WindowFullscreen.ensureListener(stage, function() {
            if (settingsTab != null)
                settingsTab.refreshFullscreenSummary();
        });
        WindowFullscreen.applyFromConfig(stage);

        ensureGameEndOverlay();
        if (boardContainer != null) {
            if (!boardContainer.contains(gameEndOverlay))
                boardContainer.addChild(gameEndOverlay);
            else
                boardContainer.addChild(gameEndOverlay);
        }
        var promotionMenu = controller.getPromotionMenu();
        if (contains(promotionMenu))
            removeChild(promotionMenu);
        addChild(promotionMenu);
        syncGameEndOverlay();
    }

    private function applyFullscreenFromConfig():Void {
        WindowFullscreen.applyFromConfig(stage);
    }

    private function toggleWindowFullscreen():Void {
        WindowFullscreen.toggleAndSave(stage, function() {
            if (settingsTab != null)
                settingsTab.refreshFullscreenSummary();
        });
    }
    
    /**
     * Engine player and UCI listeners are registered once (not on every window rebuild).
     */
    private function initEngineIntegrationOnce():Void {
        if (engineIntegrationInit)
            return;
        engineIntegrationInit = true;
        enginePlayer = new EnginePlayer(controller);
        enginePlayer.playWhile = function() {
            return isGameTabActive() && !isTimeoutActive();
        };
        enginePlayer.getClockTimesMs = function() {
            return getActiveClockTimesForEngine();
        };
        enginePlayer.addEventListener(EnginePlayer.ENGINE_THINKING, onEngineThinking);
        enginePlayer.addEventListener(EnginePlayer.ENGINE_MOVED, engineMoveHandler.onEngineMoved);
        var uci = UCIManager.getInstance();
        uci.addEventListener(UCIManager.ENGINE_READY, onEngineReady);
        uci.addEventListener(UCIManager.ENGINE_ERROR, onEngineError);
        uci.addEventListener(UCIManager.BEST_MOVE, onEngineMove);
        uci.addEventListener(UCIManager.ENGINE_OPTIONS_READY, onEngineOptionsReady);
    }
    
    private function onEngineOptionsReady(_:Event):Void {
        if (enginesTab != null)
            enginesTab.refreshSpinHints();
    }
    
    private function onEngineReady(e:Event):Void {
        var uci = UCIManager.getInstance();
        SettingsConfig.engineConnected = true;
        SettingsConfig.engineName = uci.getEngineName();
        if (enginesTab != null)
            enginesTab.updateEngineUI();
        if (!engineSessionInitialized) {
            engineSessionInitialized = true;
            uci.applyPersistedSpinOptions();
        }
        syncEngineVariantForCurrentBoard();
        checkEngineTurn();
    }
    
    private function onEngineError(e:Event):Void {
        SettingsConfig.engineConnected = false;
        engineSessionInitialized = false;
        engineVariantSync.resetMode();
        if (enginePlayer != null)
            enginePlayer.thinking = false;
        if (enginesTab != null)
            enginesTab.updateEngineUI();
    }

    private function clockVisualStyle():ClockVisualStyle {
        return {
            gameTab: currentTab == 0,
            initialMs: initialClockMs,
            clocksStarted: clocksStarted,
            browsingHistory: controller.isBrowsingHistory(),
            terminal: GameEndCopy.isTerminalGameState(controller.getGameState()),
            timeoutActive: isTimeoutActive(),
            turnW: controller.getCurrentTurn() == "w",
        };
    }

    private function isTimeoutActive():Bool {
        return timeoutWinner != "";
    }

    private function ensureGameEndOverlay():Void {
        if (gameEndOverlay != null)
            return;
        gameEndOverlay = new GameEndOverlay();
        gameEndOverlay.onDismissRequest = function() {
            gameEndOverlayDismissedKey = gameEndOverlayActiveKey;
        };
    }

    private function clearGameEndOverlayState():Void {
        gameEndOverlayActiveKey = "";
        gameEndOverlayDismissedKey = "";
        if (gameEndOverlay != null)
            gameEndOverlay.dismiss();
    }

    private function syncGameEndOverlay():Void {
        ensureGameEndOverlay();
        if (boardContainer == null)
            return;

        if (currentTab != 0 || controller.isBrowsingHistory()) {
            gameEndOverlay.visible = false;
            return;
        }

        var gs = controller.getGameState();
        var terminal = GameEndCopy.isTerminalGameState(gs);
        var timedOut = isTimeoutActive();
        if (!terminal && !timedOut) {
            clearGameEndOverlayState();
            return;
        }

        var key = GameEndCopy.overlayDismissKey(gs, timeoutWinner);
        if (key == gameEndOverlayDismissedKey)
            return;

        if (key == gameEndOverlayActiveKey && gameEndOverlay.visible) {
            gameEndOverlay.layout(gameBoardViewW, gameBoardViewH);
            return;
        }

        var copy = GameEndCopy.buildOverlayCopy(gs, timeoutWinner, controller.getCurrentTurn());
        gameEndOverlayActiveKey = key;
        gameEndOverlay.reveal(gameBoardViewW, gameBoardViewH, copy.title, copy.subtitle, copy.confetti);

        if (!boardContainer.contains(gameEndOverlay))
            boardContainer.addChild(gameEndOverlay);
        else
            boardContainer.addChild(gameEndOverlay);
        var promotionMenu = controller.getPromotionMenu();
        if (contains(promotionMenu))
            removeChild(promotionMenu);
        addChild(promotionMenu);
    }

    private function clockPillWidth(boardSize:Int):Int {
        return IntBounds.clampi(Std.int(boardSize * 0.36), 104, 176);
    }

    /** Repositions board vertical inset, right-aligned history, and clock pills for timed/untimed. */
    private function syncGameClockLayout():Void {
        if (uiPanel == null || boardContainer == null)
            return;
        var timed = initialClockMs > 0;
        var contentX = uiPanel.x + uiPanel.getContentX();
        var contentY = uiPanel.y + uiPanel.getContentY();
        var inset = timed ? GameClockView.verticalInsetTimed() : 0;
        boardContainer.y = contentY + inset;
        var innerW = uiPanel.getContentWidth();
        if (moveHistoryPanel != null) {
            moveHistoryPanel.x = contentX + innerW - moveHistoryPanel.getPanelWidth();
            moveHistoryPanel.y = boardContainer.y;
        }
        if (clockView == null)
            clockView = new GameClockView();
        clockView.rebuild(this, boardContainer.x, boardContainer.y, gameBoardViewW, gameBoardViewH, timed, clockPillWidth(gameBoardViewW));
        clockView.setRootsVisible(currentTab == 0 && timed);
    }

    private function refreshClockLabels():Void {
        if (clockView == null)
            return;
        if (initialClockMs <= 0) {
            clockView.clearFrom(this);
            return;
        }
        if (clockView.whiteRoot == null || clockView.blackRoot == null)
            return;
        clockView.setTexts(ClockFormat.formatMsCeilToSeconds(whiteClockMs), ClockFormat.formatMsCeilToSeconds(blackClockMs));
        clockView.snapVisualsToTargets(clockVisualStyle());
    }

    private function resetClocksForPreset():Void {
        initialClockMs = SettingsTimePresets.presetToMs(SettingsConfig.timeControlPreset);
        whiteClockMs = initialClockMs;
        blackClockMs = initialClockMs;
        timeoutWinner = "";
        clocksStarted = false;
        lastClockStamp = Timer.stamp();
        clockHistoryLenBaseline = controller.getMoveHistory().length;
        clearGameEndOverlayState();
        syncGameClockLayout();
        refreshClockLabels();
    }

    /** Add Fischer increment for each new half-move in history (index 0 = White). */
    private function applyClockIncrementForNewMoves():Void {
        if (initialClockMs <= 0 || isTimeoutActive())
            return;
        var incSec = SettingsConfig.clockIncrementSeconds;
        if (incSec <= 0)
            return;
        var len = controller.getMoveHistory().length;
        if (len < clockHistoryLenBaseline)
            clockHistoryLenBaseline = len;
        if (len <= clockHistoryLenBaseline)
            return;
        var incMs = incSec * 1000.0;
        for (i in clockHistoryLenBaseline...len) {
            if (i % 2 == 0)
                whiteClockMs += incMs;
            else
                blackClockMs += incMs;
        }
        clockHistoryLenBaseline = len;
        refreshClockLabels();
    }

    private function onEnterFrame(_:Event):Void {
        if (historyReplay != null && currentTab == 0 && !isTimeoutActive() && (historyLeftHeld || historyRightHeld)) {
            var now = Timer.stamp();
            if (now - lastHistoryHoldStepStamp >= HISTORY_HOLD_STEP_INTERVAL_SEC) {
                var stepped = historyLeftHeld
                    ? historyReplay.tryStepHistoryBackward(isTimeoutActive())
                    : historyReplay.tryStepHistoryForward(isTimeoutActive());
                if (stepped)
                    lastHistoryHoldStepStamp = now;
            }
        }

        syncGameEndOverlay();
        var now = Timer.stamp();
        if (clockView != null && initialClockMs > 0) {
            var dtVis = clockView.consumeFrameDtMs();
            clockView.tickVisuals(dtVis, clockVisualStyle());
        }

        if (initialClockMs <= 0)
            return;
        var dtMs = (now - lastClockStamp) * 1000.0;
        if (dtMs < 0)
            dtMs = 0;
        lastClockStamp = now;
        if (dtMs == 0)
            return;
        if (currentTab != 0 || controller.isBrowsingHistory() || GameEndCopy.isTerminalGameState(controller.getGameState()) || isTimeoutActive())
            return;
        if (!clocksStarted) {
            if (controller.getMoveHistory().length <= 0)
                return;
            clocksStarted = true;
            lastClockStamp = now;
            refreshClockLabels();
            return;
        }

        if (controller.getCurrentTurn() == "w") {
            whiteClockMs -= dtMs;
            if (whiteClockMs <= 0) {
                whiteClockMs = 0;
                timeoutWinner = "b";
                trace("Time forfeit: Black wins on time.");
                onTimeoutReached();
            }
        } else {
            blackClockMs -= dtMs;
            if (blackClockMs <= 0) {
                blackClockMs = 0;
                timeoutWinner = "w";
                trace("Time forfeit: White wins on time.");
                onTimeoutReached();
            }
        }
        refreshClockLabels();
    }

    private function onTimeoutReached():Void {
        var uci = UCIManager.getInstance();
        if (uci.isEngineReady())
            uci.stopCalculation();
        if (enginePlayer != null)
            enginePlayer.thinking = false;
        SoundManager.getInstance().play(SoundManager.GAME_END);
        syncGameEndOverlay();
    }

    private function getActiveClockTimesForEngine():{white:Int, black:Int} {
        if (initialClockMs <= 0 || isTimeoutActive() || !clocksStarted)
            return null;
        return {
            white: Std.int(Math.max(0, Math.floor(whiteClockMs))),
            black: Std.int(Math.max(0, Math.floor(blackClockMs)))
        };
    }
    
    private function onEngineMove(e:managers.UCIManager.UCIEvent):Void {
        trace("Engine suggests: " + e.data);
    }
        
    private function onEngineThinking(e:Event):Void {
        trace("Engine is thinking...");
        // Could show a "thinking" indicator here
    }

    private function syncEngineVariantForCurrentBoard(?force:Bool = false):Void {
        engineVariantSync.syncForBoard(controller.getBoardData(), UCIManager.getInstance(), force);
    }

    private function checkEngineTurn():Void {
        if (isTimeoutActive())
            return;
        syncEngineVariantForCurrentBoard();
        if (enginePlayer != null) {
            enginePlayer.checkAndPlay();
        }
    }
    
    private function onTabChange(index:Int):Void {
        currentTab = index;
        historyLeftHeld = false;
        historyRightHeld = false;
        updateTabVisibility();
    }
    
    private function updateTabVisibility():Void {
        boardContainer.visible = (currentTab == 0);
        settingsContainer.visible = (currentTab == 1);
        if (enginesContainer != null)
            enginesContainer.visible = (currentTab == 2);
        if (layoutMakerContainer != null)
            layoutMakerContainer.visible = (currentTab == 3);

        if (mouseHandler != null) {
            mouseHandler.setEnabled(currentTab == 0 && !isTimeoutActive());
        }
        
        if (currentTab == 3 && layoutMakerTab != null)
            layoutMakerTab.refreshDropdownFromSettings();

        if (currentTab == 0) {
            // Board + pieces stay in sync while the game tab was hidden; do not full `pieceRenderer.render`
            // here — it would Actuate.stop all sprites and cancel spawn/death tweens right after setupUI.
            var hints = controller.getLegalMovesForSelection();
            var captureHints = controller.getCaptureMovesForSelection();
            boardRenderer.setCheckHighlights(controller.getCheckedRoyals());
            boardRenderer.render(controller.getSelectedTile(), hints, captureHints, controller.getLastMoveHighlightFrom(), controller.getLastMoveHighlightTo());
            boardAnnotations.redraw();
            refreshMoveHistory();
            checkEngineTurn();
        }
        moveHistoryPanel.visible = (currentTab == 0);
        if (clockView != null)
            clockView.setRootsVisible(currentTab == 0 && initialClockMs > 0);
        syncGameEndOverlay();
    }

    private function isGameTabActive():Bool {
        return currentTab == 0;
    }

    private function refreshMoveHistory():Void {
        applyClockIncrementForNewMoves();
        if (moveHistoryPanel != null)
            moveHistoryPanel.setMoves(controller.getMoveHistory(), controller.getGameState());
        syncGameEndOverlay();
    }

    private function onKeyDown(e:KeyboardEvent):Void {
        if (e.keyCode == Keyboard.F11) {
            toggleWindowFullscreen();
            return;
        }
        if (e.keyCode == Keyboard.R && currentTab == 0 && boardViewPort != null) {
            boardViewPort.resetView();
            return;
        }
        if (currentTab == 0 && !isTimeoutActive() && controller.getMoveHistory().length > 0) {
            if (e.keyCode == Keyboard.LEFT) {
                historyLeftHeld = true;
                historyRightHeld = false;
            } else if (e.keyCode == Keyboard.RIGHT) {
                historyRightHeld = true;
                historyLeftHeld = false;
            }
        }
        if (historyReplay != null && historyReplay.tryHandleKey(currentTab == 0, isTimeoutActive(), e)) {
            lastHistoryHoldStepStamp = Timer.stamp();
            return;
        }
    }

    private function onKeyUp(e:KeyboardEvent):Void {
        if (e.keyCode == Keyboard.LEFT)
            historyLeftHeld = false;
        if (e.keyCode == Keyboard.RIGHT)
            historyRightHeld = false;
    }
    
    private function onPromotionCompleted():Void {
        mouseHandler.onPromotionCompleted();
        refreshMoveHistory();

        // Check if engine should play next
        checkEngineTurn();
    }

    private function onStageRightMouseDown(e:MouseEvent):Void {
        if (currentTab != 0 || boardAnnotations == null)
            return;
        if (boardWorld == null)
            return;
        if (summonContextMenu != null)
            closeSummonContextMenu();
        var pt = boardWorld.globalToLocal(new Point(e.stageX, e.stageY));
        var boardPixelW = tileSize * GameConfig.boardCols;
        var boardPixelH = tileSize * GameConfig.boardRows;
        if (pt.x < 0 || pt.y < 0 || pt.x >= boardPixelW || pt.y >= boardPixelH)
            return;
        if (e.shiftKey) {
            boardAnnotations.clearAll();
            return;
        }
        rtStartCol = Math.floor(pt.x / tileSize);
        rtStartRow = Math.floor(pt.y / tileSize);
        rtStartStageX = e.stageX;
        rtStartStageY = e.stageY;
        if (SettingsConfig.allowIllegalMoves) {
            rtAnnotating = false;
            scheduleRightClickHold();
            stage.addEventListener(MouseEvent.MOUSE_MOVE, onStageRightMouseMove);
            stage.addEventListener(MouseEvent.RIGHT_MOUSE_UP, onStageRightMouseUp);
            return;
        }
        rtAnnotating = true;
        stage.addEventListener(MouseEvent.MOUSE_MOVE, onStageRightMouseMove);
        stage.addEventListener(MouseEvent.RIGHT_MOUSE_UP, onStageRightMouseUp);
    }

    private function onStageRightMouseMove(e:MouseEvent):Void {
        if (rtHoldPending && !rtHoldActivated) {
            var dx = e.stageX - rtStartStageX;
            var dy = e.stageY - rtStartStageY;
            if (dx * dx + dy * dy > 64) {
                cancelRightClickHold();
                rtAnnotating = true;
            }
        }

        if (!rtAnnotating || boardAnnotations == null)
            return;
        if (boardWorld == null)
            return;
        var pt = boardWorld.globalToLocal(new Point(e.stageX, e.stageY));
        var boardPixelW = tileSize * GameConfig.boardCols;
        var boardPixelH = tileSize * GameConfig.boardRows;
        var ec = Math.floor(pt.x / tileSize);
        var er = Math.floor(pt.y / tileSize);
        ec = IntBounds.clampi(ec, 0, GameConfig.boardCols - 1);
        er = IntBounds.clampi(er, 0, GameConfig.boardRows - 1);
        if (pt.x < 0 || pt.y < 0 || pt.x >= boardPixelW || pt.y >= boardPixelH) {
            boardAnnotations.redraw();
            return;
        }
        boardAnnotations.redraw(rtStartCol, rtStartRow, ec, er);
    }

    private function onStageRightMouseUp(e:MouseEvent):Void {
        cancelRightClickHold();
        if (rtHoldActivated) {
            rtHoldActivated = false;
            rtAnnotating = false;
            stage.removeEventListener(MouseEvent.MOUSE_MOVE, onStageRightMouseMove);
            stage.removeEventListener(MouseEvent.RIGHT_MOUSE_UP, onStageRightMouseUp);
            return;
        }

        stage.removeEventListener(MouseEvent.MOUSE_MOVE, onStageRightMouseMove);
        stage.removeEventListener(MouseEvent.RIGHT_MOUSE_UP, onStageRightMouseUp);

        if (boardAnnotations == null || boardWorld == null)
            return;

        var dx = e.stageX - rtStartStageX;
        var dy = e.stageY - rtStartStageY;
        var distSq = dx * dx + dy * dy;
        var pt = boardWorld.globalToLocal(new Point(e.stageX, e.stageY));
        var endC = Math.floor(pt.x / tileSize);
        var endR = Math.floor(pt.y / tileSize);

        if (!rtAnnotating) {
            if (distSq < 64) {
                boardAnnotations.toggleHighlight(rtStartCol, rtStartRow);
            } else if (endC >= 0 && endC < GameConfig.boardCols && endR >= 0 && endR < GameConfig.boardRows) {
                boardAnnotations.toggleArrow(rtStartCol, rtStartRow, endC, endR);
            } else {
                boardAnnotations.redraw();
            }
            rtAnnotating = false;
            return;
        }

        rtAnnotating = false;

        if (distSq < 64) {
            boardAnnotations.toggleHighlight(rtStartCol, rtStartRow);
        } else if (endC >= 0 && endC < GameConfig.boardCols && endR >= 0 && endR < GameConfig.boardRows) {
            boardAnnotations.toggleArrow(rtStartCol, rtStartRow, endC, endR);
        } else {
            boardAnnotations.redraw();
        }
    }

    private function scheduleRightClickHold():Void {
        cancelRightClickHold();
        rtHoldPending = true;
        rtHoldActivated = false;
        rtHoldTimer = haxe.Timer.delay(onRightClickHoldTriggered, 300);
    }

    private function cancelRightClickHold():Void {
        if (rtHoldTimer != null) {
            rtHoldTimer.stop();
            rtHoldTimer = null;
        }
        rtHoldPending = false;
    }

    private function onRightClickHoldTriggered():Void {
        rtHoldTimer = null;
        if (!rtHoldPending)
            return;
        rtHoldPending = false;
        rtHoldActivated = true;
        if (!SettingsConfig.allowIllegalMoves)
            return;
        showSummonContextMenu(rtStartCol, rtStartRow, rtStartStageX, rtStartStageY);
    }

    private function showSummonContextMenu(col:Int, row:Int, stageX:Float, stageY:Float):Void {
        closeSummonContextMenu();
        summonMenuTile = { col: col, row: row };
        summonContextMenu = new Sprite();

        var menuW = 180;
        var menuH = 34;
        var bg = new Shape();
        bg.graphics.beginFill(0x2A2A2A, 0.96);
        bg.graphics.lineStyle(1, 0x555555);
        bg.graphics.drawRoundRect(0, 0, menuW, menuH, 10, 10);
        bg.graphics.endFill();
        summonContextMenu.addChild(bg);

        var button = new ui.UIButton(menuW - 8, 26, "Summon Piece", 0x333333, 0x606060);
        button.x = 4;
        button.y = 4;
        button.setOnClick(function() {
            showSummonPieceList();
        });
        summonContextMenu.addChild(button);

        summonPieceList = new Sprite();
        summonPieceList.x = 0;
        summonPieceList.y = menuH + 4;
        summonPieceList.visible = false;
        summonContextMenu.addChild(summonPieceList);

        summonContextMenu.x = Math.max(6, Math.min(stageX, stage.stageWidth - menuW - 6));
        summonContextMenu.y = Math.max(6, Math.min(stageY, stage.stageHeight - menuH - 6));
        stage.addChild(summonContextMenu);
        stage.addEventListener(MouseEvent.MOUSE_DOWN, onStageMouseDownSummon, false, 0, true);
        if (mouseHandler != null)
            mouseHandler.setEnabled(false);
    }

    private function showSummonPieceList():Void {
        if (summonContextMenu == null || summonPieceList == null)
            return;
        summonPieceList.visible = true;
        while (summonPieceList.numChildren > 0)
            summonPieceList.removeChildAt(0);

        var pieceTypes = PieceCatalog.allTypeIds();
        var itemH = 28;
        var listW = 180;
        var listY = 4;
        var listHeight = pieceTypes.length * (itemH + 4) + 4;

        var bg = new Shape();
        bg.graphics.beginFill(0x2A2A2A, 0.96);
        bg.graphics.lineStyle(1, 0x555555);
        bg.graphics.drawRoundRect(0, 0, listW, listHeight, 10, 10);
        bg.graphics.endFill();
        summonPieceList.addChild(bg);

        for (type in pieceTypes) {
            var label = type.length > 0 ? type.charAt(0).toUpperCase() + type.substr(1) : type;
            var row = new ui.UIButton(listW - 8, itemH, label, 0x3A3A3A, 0x555555);
            row.x = 4;
            row.y = listY;
            var capturedType = type;
            row.setOnClick(function() {
                onSummonPieceSelected(capturedType);
            });
            summonPieceList.addChild(row);
            listY += itemH + 4;
        }

        var totalHeight = (summonPieceList.y + listHeight) + summonContextMenu.y;
        if (totalHeight > stage.stageHeight - 6) {
            summonContextMenu.y = Math.max(6, stage.stageHeight - totalHeight - 6);
        }
    }

    private function onSummonPieceSelected(type:String):Void {
        if (summonMenuTile == null)
            return;
        var color = controller.getCurrentTurn();
        controller.setPieceAt(summonMenuTile.col, summonMenuTile.row, type + "-" + color);
        boardRenderer.setCheckHighlights(controller.getCheckedRoyals());
        boardRenderer.render(controller.getSelectedTile(), null, null, controller.getLastMoveHighlightFrom(), controller.getLastMoveHighlightTo());
        pieceRenderer.render(controller.getBoardData());
        closeSummonContextMenu();
    }

    private function onStageMouseDownSummon(e:MouseEvent):Void {
        if (summonContextMenu == null)
            return;
        var target = cast(e.target, openfl.display.DisplayObject);
        while (target != null) {
            if (target == summonContextMenu)
                return;
            target = target.parent;
        }
        closeSummonContextMenu();
    }

    private function closeSummonContextMenu():Void {
        if (summonPieceList != null) {
            while (summonPieceList.numChildren > 0)
                summonPieceList.removeChildAt(0);
            summonPieceList = null;
        }
        if (summonContextMenu != null && summonContextMenu.parent != null)
            summonContextMenu.parent.removeChild(summonContextMenu);
        summonContextMenu = null;
        summonMenuTile = null;
        if (stage != null)
            stage.removeEventListener(MouseEvent.MOUSE_DOWN, onStageMouseDownSummon, false);
        if (mouseHandler != null)
            mouseHandler.setEnabled(true);
    }

    private function onResize(e:Event):Void {
        setupUI(true);
        initEngineIntegrationOnce();
        if (settingsTab != null)
            settingsTab.syncInputsFromConfig();
        if (enginesTab != null)
            enginesTab.syncInputsFromConfig();

        // Update mouse handler with new board container
        mouseHandler.setBoardContainer(boardWorld);
        mouseHandler.setBoardViewPort(boardViewPort);
        mouseHandler.setTileSize(tileSize);
    }
}
