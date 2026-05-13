package game;

import config.SettingsConfig;
import interfaces.IBoardRenderer;
import interfaces.IGameController;
import interfaces.IPieceRenderer;
import openfl.events.KeyboardEvent;
import openfl.geom.Point;
import openfl.ui.Keyboard;
import pieces.PieceFactory;
import managers.SoundManager;
import managers.ValidationManager;
import utils.BoardUtils;
import utils.ChessNotation;
import ui.BoardAnnotations;
import utils.MouseHandler;
import haxe.Timer;

/** Arrow-key replay through the move list (instant snap — no tweens so key repeat is fast). */
class HistoryReplayController {
    var mouseHandler:MouseHandler;
    var controller:IGameController;
    var boardRenderer:IBoardRenderer;
    var pieceRenderer:IPieceRenderer;
    var boardAnnotations:BoardAnnotations;

    public var onAfterFinishHistory:Void->Void;

    var historyReplaySpawnSquare:Null<{r:Int, c:Int, id:String}>;
    var lastHistorySoundStamp:Float = -999.0;

    public function new(mouseHandler:MouseHandler, controller:IGameController, boardRenderer:IBoardRenderer,
            pieceRenderer:IPieceRenderer, boardAnnotations:BoardAnnotations) {
        this.mouseHandler = mouseHandler;
        this.controller = controller;
        this.boardRenderer = boardRenderer;
        this.pieceRenderer = pieceRenderer;
        this.boardAnnotations = boardAnnotations;
    }

    /** `Main.setupUI` recreates annotations; keep replay finish in sync. */
    public function setBoardAnnotations(b:BoardAnnotations):Void {
        this.boardAnnotations = b;
    }

    /**
     * @return true if the key was consumed (history step started).
     */
    public function tryHandleKey(gameTab:Bool, timeoutActive:Bool, e:KeyboardEvent):Bool {
        if (!gameTab)
            return false;
        if (e.keyCode == Keyboard.LEFT)
            return tryStepHistoryBackward(timeoutActive);
        if (e.keyCode == Keyboard.RIGHT)
            return tryStepHistoryForward(timeoutActive);
        return false;
    }

    /** One step back in the move list (same guards as arrow keys). Used for per-frame hold polling. */
    public function tryStepHistoryBackward(timeoutActive:Bool):Bool {
        if (mouseHandler.getIsAnimating())
            return false;
        if (timeoutActive)
            return false;
        var full = controller.getMoveHistory();
        if (full.length == 0)
            return false;
        var ply = controller.getHistoryViewPly();
        if (ply <= 0)
            return false;
        historyAnimateBackward(full, ply);
        return true;
    }

    /** One step forward in the move list. */
    public function tryStepHistoryForward(timeoutActive:Bool):Bool {
        if (mouseHandler.getIsAnimating())
            return false;
        if (timeoutActive)
            return false;
        var full = controller.getMoveHistory();
        if (full.length == 0)
            return false;
        var ply = controller.getHistoryViewPly();
        if (ply >= full.length)
            return false;
        historyAnimateForward(full, ply);
        return true;
    }

    function playHistorySound(fn:Void->Void):Void {
        var t = Timer.stamp();
        if (t - lastHistorySoundStamp < 0.05)
            return;
        lastHistorySoundStamp = t;
        fn();
    }

    public function finishHistoryAnim():Void {
        mouseHandler.setAnimating(false);
        var replaySpawn = historyReplaySpawnSquare;
        historyReplaySpawnSquare = null;
        pieceRenderer.render(controller.getBoardData(), false);
        if (replaySpawn != null && replaySpawn.id != "") {
            pieceRenderer.replaySquareWithSpawn(replaySpawn.r, replaySpawn.c, replaySpawn.id);
        }
        boardRenderer.setCheckHighlights(controller.getCheckedRoyals());
        boardRenderer.render(controller.getSelectedTile(), null, null, controller.getLastMoveHighlightFrom(), controller.getLastMoveHighlightTo());
        boardAnnotations.redraw();
        if (onAfterFinishHistory != null)
            onAfterFinishHistory();
    }

    function historyAnimateForward(full:Array<String>, plyBefore:Int):Void {
        historyReplaySpawnSquare = null;
        var moveData = ChessNotation.parseUCI(full[plyBefore]);
        if (moveData == null)
            return;

        var boardBefore = BoardUtils.copyBoard(controller.getBoardData());
        var pieceId = boardBefore[moveData.fromRow][moveData.fromCol];
        var ep = BoardUtils.enPassantCaptureSquare(boardBefore, moveData.fromCol, moveData.fromRow, moveData.toCol, moveData.toRow, pieceId);
        var isCapture = boardBefore[moveData.toRow][moveData.toCol] != "" || ep != null;

        var looksLikeCastle = pieceId != "" && pieceId.indexOf("king") == 0 && Math.abs(moveData.toCol - moveData.fromCol) == 2;
        var isCastling = looksLikeCastle;
        if (looksLikeCastle && SettingsConfig.allowIllegalMoves) {
            var kpc = PieceFactory.createPiece(pieceId);
            isCastling = kpc != null
                && ValidationManager.isValidMove(kpc, new Point(moveData.fromCol, moveData.fromRow), new Point(moveData.toCol, moveData.toRow), boardBefore);
        } else if (looksLikeCastle) {
            isCastling = true;
        }

        controller.stepHistoryView(1);

        if (isCastling) {
            playHistorySound(function() SoundManager.getInstance().playCastle());
        } else {
            var gameState = controller.getGameState();
            if (gameState == "check" || gameState == "checkmate")
                playHistorySound(function() SoundManager.getInstance().playMove(true));
            else if (isCapture)
                playHistorySound(function() SoundManager.getInstance().playCapture());
            else
                playHistorySound(function() SoundManager.getInstance().playMove(false));
        }
        finishHistoryAnim();
    }

    function historyAnimateBackward(full:Array<String>, plyBefore:Int):Void {
        historyReplaySpawnSquare = null;
        var moveData = ChessNotation.parseUCI(full[plyBefore - 1]);
        if (moveData == null)
            return;

        var boardBeforeUndo = BoardUtils.copyBoard(controller.getBoardData());
        var pieceOnTo = boardBeforeUndo[moveData.toRow][moveData.toCol];

        controller.stepHistoryView(-1);
        var b = controller.getBoardData();
        var moverOnFrom = b[moveData.fromRow][moveData.fromCol];
        var ep = BoardUtils.enPassantCaptureSquare(b, moveData.fromCol, moveData.fromRow, moveData.toCol, moveData.toRow, moverOnFrom);
        var isCapture = b[moveData.toRow][moveData.toCol] != "" || ep != null;

        if (isCapture) {
            var vr = moveData.toRow;
            var vc = moveData.toCol;
            if (ep != null) {
                vr = Std.int(ep.y);
                vc = Std.int(ep.x);
            }
            var victimId = b[vr][vc];
            if (victimId != "")
                historyReplaySpawnSquare = {r: vr, c: vc, id: victimId};
        }

        var looksLikeCastle = pieceOnTo != "" && pieceOnTo.indexOf("king") == 0 && Math.abs(moveData.toCol - moveData.fromCol) == 2;
        var isCastling = looksLikeCastle;
        if (looksLikeCastle && SettingsConfig.allowIllegalMoves) {
            var kpc = PieceFactory.createPiece(pieceOnTo);
            isCastling = kpc != null
                && ValidationManager.isValidMove(kpc, new Point(moveData.toCol, moveData.toRow), new Point(moveData.fromCol, moveData.fromRow), boardBeforeUndo);
        } else if (looksLikeCastle) {
            isCastling = true;
        }

        if (isCastling) {
            playHistorySound(function() SoundManager.getInstance().playCastle());
        } else {
            var gameState = controller.getGameState();
            if (gameState == "check" || gameState == "checkmate")
                playHistorySound(function() SoundManager.getInstance().playMove(true));
            else if (isCapture)
                playHistorySound(function() SoundManager.getInstance().playCapture());
            else
                playHistorySound(function() SoundManager.getInstance().playMove(false));
        }
        finishHistoryAnim();
    }
}
