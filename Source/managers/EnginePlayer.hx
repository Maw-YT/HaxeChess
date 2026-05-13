package managers;

import config.SettingsConfig;
import utils.BoardUtils;
import utils.ChessNotation.MoveCoords;
import openfl.events.Event;
import openfl.events.EventDispatcher;
import haxe.Timer;
import openfl.Lib;
#if sys
import sys.thread.Thread;
import sys.thread.Deque;
#end

/**
 * Handles the chess engine's play
 * Requests moves from UCIManager and applies them to the game
 */
class EnginePlayer extends EventDispatcher {
    private var controller:interfaces.IGameController;
    private var uci:UCIManager;
    #if sys
    private var builtinResultQueue:Deque<Dynamic>;
    private var builtinPollTimer:Timer;
    private var builtinSearchToken:Int = 0;
    private var builtinSearchStartedMs:Int = 0;
    #end
    
    inline function usingBuiltInEngine():Bool {
        return SettingsConfig.uciEnginePath == SettingsConfig.BUILTIN_ENGINE_PATH;
    }

    /** When set, engine only searches / applies moves while this returns true (e.g. Game tab visible). */
    public var playWhile:Void->Bool;
    /** Optional live chess clocks in ms; when present, passed to UCI as wtime/btime. */
    public var getClockTimesMs:Void->{white:Int, black:Int};

    /** True while waiting for UCI bestmove (human must not move on the engine's turn). */
    public var thinking:Bool = false;
    
    // Events
    public static inline var ENGINE_MOVED:String = "engineMoved";
    public static inline var ENGINE_THINKING:String = "engineThinking";
    
    public function new(controller:interfaces.IGameController) {
        super();
        this.controller = controller;
        this.uci = UCIManager.getInstance();
        #if sys
        builtinResultQueue = new Deque();
        #end
    }
    
    /**
     * Check if it's the engine's turn and request a move if so
     */
    public function checkAndPlay():Bool {
        if (thinking)
            return false;
        if (controller.isBrowsingHistory())
            return false;
        if (playWhile != null && !playWhile())
            return false;
        if (!usingBuiltInEngine() && !uci.isEngineReady()) return false;
        if (!SettingsConfig.engineConnected) return false;

        var gs = controller.getGameState();
        if (gs == "checkmate" || gs == "stalemate" || gs == "draw_repetition" || gs == "draw_material"
            || gs == "draw_no_royals" || gs == "win_white" || gs == "win_black")
            return false;
        
        var currentTurn = controller.getCurrentTurn();
        var engineColor = SettingsConfig.enginePlayAs;
        
        // Check if engine should play this turn
        var shouldPlay = false;
        if (engineColor == "both") {
            shouldPlay = true;
        } else if (engineColor == "white" && currentTurn == "w") {
            shouldPlay = true;
        } else if (engineColor == "black" && currentTurn == "b") {
            shouldPlay = true;
        }
        
        if (shouldPlay) {
            requestEngineMove();
            return true;
        }
        
        return false;
    }
    
    /**
     * Request a move from the engine
     */
    /**
     * Whether the human may drag/click pieces (false on engine's turn or while engine is thinking).
     */
    public function humanMayMovePieces(ctrl:interfaces.IGameController):Bool {
        if (thinking)
            return false;
        if (!SettingsConfig.engineConnected)
            return true;
        var t = ctrl.getCurrentTurn();
        var m = SettingsConfig.enginePlayAs;
        if (m == "both")
            return false;
        if (m == "white" && t == "w")
            return false;
        if (m == "black" && t == "b")
            return false;
        return true;
    }

    private function requestEngineMove():Void {
        thinking = true;
        dispatchEvent(new Event(ENGINE_THINKING));

        if (usingBuiltInEngine()) {
            var boardSnapshot = BoardUtils.copyBoard(controller.getBoardData());
            var turnSnapshot = controller.getCurrentTurn();
            // Respect configured depth; cap only to keep the UI thread worker bounded on huge depths.
            var depthSnapshot = Std.int(Math.max(1, Math.min(SettingsConfig.engineDepth, 32)));
            var thinkBudgetMs = computeBuiltinThinkTimeMs(turnSnapshot);
            #if sys
            var token = ++builtinSearchToken;
            if (builtinPollTimer != null) {
                builtinPollTimer.stop();
                builtinPollTimer = null;
            }
            builtinSearchStartedMs = Lib.getTimer();
            Thread.create(function() {
                try {
                    engine.Search.clearStop();
                    var move = BuiltinEngine.chooseMoveFromSnapshot(boardSnapshot, turnSnapshot, depthSnapshot, thinkBudgetMs);
                    builtinResultQueue.add({token: token, ok: true, move: move});
                } catch (e:Dynamic) {
                    builtinResultQueue.add({token: token, ok: false, move: "", err: Std.string(e)});
                }
            });
            builtinPollTimer = new Timer(16);
            builtinPollTimer.run = function() {
                var msg:Dynamic = builtinResultQueue.pop(false);
                if (msg == null) {
                    // Fail-safe: never let built-in engine hang indefinitely.
                    if (Lib.getTimer() - builtinSearchStartedMs > 8000) {
                        if (builtinPollTimer != null) {
                            builtinPollTimer.stop();
                            builtinPollTimer = null;
                        }
                        BuiltinEngine.requestStop();
                        // Guaranteed fallback so the engine still plays.
                        onEngineMove(BuiltinEngine.chooseMoveFromSnapshot(boardSnapshot, turnSnapshot, 1, 120));
                    }
                    return;
                }
                if (builtinPollTimer != null) {
                    builtinPollTimer.stop();
                    builtinPollTimer = null;
                }
                if (msg.token != builtinSearchToken)
                    return;
                if (!thinking)
                    return;
                if (msg.ok != true) {
                    BuiltinEngine.requestStop();
                    // Worker failed; fall back to a cheap 1-ply move.
                    onEngineMove(BuiltinEngine.chooseMoveFromSnapshot(boardSnapshot, turnSnapshot, 1, 120));
                    return;
                }
                if (BuiltinEngine.lastSearchInfo != null) {
                    var si = BuiltinEngine.lastSearchInfo;
                    UCIManager.getInstance().emitInfoLine("[builtin] depth=" + si.depthReached + " score=" + si.bestScore
                        + " nodes=" + si.nodes + " nps=" + si.nps + " ms=" + si.elapsedMs + " stop=" + si.stopReason);
                }
                onEngineMove(Std.string(msg.move));
            };
            #else
            haxe.Timer.delay(function() {
                if (playWhile != null && !playWhile()) {
                    thinking = false;
                    return;
                }
                onEngineMove(BuiltinEngine.chooseMoveFromSnapshot(boardSnapshot, turnSnapshot, depthSnapshot, thinkBudgetMs));
            }, 1);
            #end
            return;
        }

        // Provide full context to UCI: starting position + all played moves.
        var startFen = controller.getEngineStartFEN();
        var moves = controller.getMoveHistory();
        uci.setPositionFenMoves(startFen, moves);
        var clocks = (getClockTimesMs != null) ? getClockTimesMs() : null;
        if (clocks != null)
            uci.getBestMove(onEngineMove, SettingsConfig.engineDepth, SettingsConfig.engineTimeMs, clocks.white, clocks.black);
        else
            uci.getBestMove(onEngineMove, SettingsConfig.engineDepth, SettingsConfig.engineTimeMs);
    }

    private function computeBuiltinThinkTimeMs(turnSnapshot:String):Int {
        var fallback = SettingsConfig.engineTimeMs > 0 ? SettingsConfig.engineTimeMs : 1200;
        var clocks = (getClockTimesMs != null) ? getClockTimesMs() : null;
        if (clocks == null)
            return Std.int(Math.max(120, Math.min(5000, fallback)));

        var own = turnSnapshot == "w" ? clocks.white : clocks.black;
        if (own <= 0)
            return 120;
        var incMs = Std.int(Math.max(0, SettingsConfig.clockIncrementSeconds * 1000));
        // Simple practical policy: spend ~4% of remaining time plus 40% of increment.
        var target = Std.int(own * 0.04 + incMs * 0.40);
        var hardMax = Std.int(Math.max(120, own * 0.35));
        if (fallback > 0)
            target = Std.int(Math.min(target, fallback));
        target = Std.int(Math.max(120, Math.min(target, hardMax)));
        return target;
    }
    
    /**
     * Handle the engine's move response
     */
    private function onEngineMove(uciMove:String):Void {
        thinking = false;
        if (playWhile != null && !playWhile())
            return;
        if (uciMove == null || uciMove == "") {
            trace("Engine returned no move");
            return;
        }
        
        trace("Engine move: " + uciMove);
        
        // Parse UCI move (e.g., "e2e4" or "e7e8q" for promotion)
        var moveData = utils.ChessNotation.parseUCI(uciMove);
        if (moveData == null) {
            trace("Failed to parse engine move: " + uciMove);
            return;
        }
        
        var boardBefore = BoardUtils.copyBoard(controller.getBoardData());
        var pieceId = boardBefore[moveData.fromRow][moveData.fromCol];
        var isCastle = pieceId != "" && pieceId.indexOf("king") == 0
            && boardBefore[moveData.toRow][moveData.toCol] == ""
            && CastlingManager.instance != null
            && CastlingManager.instance.getCastlingSideIfMove(
                BoardUtils.parsePieceId(pieceId).color,
                boardBefore,
                moveData.fromCol,
                moveData.fromRow,
                moveData.toCol,
                moveData.toRow
            ) != null;
        var ep = BoardUtils.enPassantCaptureSquare(boardBefore, moveData.fromCol, moveData.fromRow, moveData.toCol, moveData.toRow, pieceId);
        var hasEP = ep != null;
        var epR = hasEP ? Std.int(ep.y) : 0;
        var epC = hasEP ? Std.int(ep.x) : 0;

        var uci = utils.ChessNotation.toUCI(moveData.fromCol, moveData.fromRow, moveData.toCol, moveData.toRow, moveData.promotion);
        var applied = controller.executeUCIMove(uci);

        dispatchEvent(new EngineMoveEvent(ENGINE_MOVED, boardBefore, moveData, pieceId, applied, isCastle, hasEP, epR, epC));
    }
}