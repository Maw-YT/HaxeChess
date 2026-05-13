package game;

import openfl.events.Event;
import openfl.media.SoundChannel;
import interfaces.IBoardRenderer;
import interfaces.IGameController;
import interfaces.IPieceRenderer;
import managers.EngineMoveEvent;
import managers.SoundManager;
import managers.CastlingManager;
import utils.MouseHandler;

/** Plays piece tweens and SFX when the engine applies a move. */
class EngineMoveHandler {
    var mouseHandler:MouseHandler;
    var controller:IGameController;
    var boardRenderer:IBoardRenderer;
    var pieceRenderer:IPieceRenderer;

    public var onAfterAnim:Void->Void;

    public function new(mouseHandler:MouseHandler, controller:IGameController, boardRenderer:IBoardRenderer, pieceRenderer:IPieceRenderer) {
        this.mouseHandler = mouseHandler;
        this.controller = controller;
        this.boardRenderer = boardRenderer;
        this.pieceRenderer = pieceRenderer;
    }

    public function onEngineMoved(e:Event):Void {
        if (!Std.isOfType(e, EngineMoveEvent)) {
            boardRenderer.setCheckHighlights(controller.getCheckedRoyals());
            boardRenderer.render(controller.getSelectedTile(), null, null, controller.getLastMoveHighlightFrom(), controller.getLastMoveHighlightTo());
            pieceRenderer.render(controller.getBoardData());
            if (onAfterAnim != null)
                onAfterAnim();
            return;
        }
        var ev = cast(e, EngineMoveEvent);
        if (!ev.applied || ev.pieceId == "") {
            boardRenderer.setCheckHighlights(controller.getCheckedRoyals());
            boardRenderer.render(controller.getSelectedTile(), null, null, controller.getLastMoveHighlightFrom(), controller.getLastMoveHighlightTo());
            pieceRenderer.render(controller.getBoardData());
            if (onAfterAnim != null)
                onAfterAnim();
            return;
        }

        mouseHandler.setAnimating(true);
        boardRenderer.setCheckHighlights(controller.getCheckedRoyals());
        boardRenderer.render(null, null, null, controller.getLastMoveHighlightFrom(), controller.getLastMoveHighlightTo());
        pieceRenderer.render(ev.boardBefore);

        function finishEngineAnim():Void {
            mouseHandler.setAnimating(false);
            pieceRenderer.render(controller.getBoardData());
            boardRenderer.setCheckHighlights(controller.getCheckedRoyals());
            boardRenderer.render(controller.getSelectedTile(), null, null, controller.getLastMoveHighlightFrom(), controller.getLastMoveHighlightTo());
            if (onAfterAnim != null)
                onAfterAnim();
        }

        if (ev.isCastling) {
            var sm = SoundManager.getInstance();
            var moveCh:SoundChannel = sm.playCastle();
            sm.playGameEndWithPrimaryMove(moveCh, controller.getMoveHistory().length, controller.getGameState());
            var ksr = ev.move.fromRow;
            var ksc = ev.move.fromCol;
            var kec = ev.move.toCol;
            var color = ev.pieceId.charAt(ev.pieceId.length - 1);
            var side = CastlingManager.instance != null
                ? CastlingManager.instance.getCastlingSideIfMove(color, ev.boardBefore, ev.move.fromCol, ev.move.fromRow, ev.move.toCol, ev.move.toRow)
                : null;
            var rookCols = CastlingManager.instance != null && side != null
                ? CastlingManager.instance.getCastlingRookColumns(color, side, ev.boardBefore, ev.move.fromCol)
                : {startCol: (side == "kingside" ? 7 : 0), endCol: (side == "kingside" ? 5 : 3)};
            var rookStartC = rookCols.startCol;
            var rookEndC = rookCols.endCol;
            pieceRenderer.animateCastling(ksr, ksc, ksr, kec, ksr, rookStartC, ksr, rookEndC, finishEngineAnim);
        } else {
            var gameState = controller.getGameState();
            var targetOccupied = ev.boardBefore[ev.move.toRow][ev.move.toCol] != "";
            var isCapture = targetOccupied || ev.hasEnPassantVictim;
            var sm = SoundManager.getInstance();
            var moveCh:SoundChannel = null;
            if (gameState == "check" || gameState == "checkmate")
                moveCh = sm.playMove(true);
            else if (isCapture)
                moveCh = sm.playCapture();
            else
                moveCh = sm.playMove(false);
            sm.playGameEndWithPrimaryMove(moveCh, controller.getMoveHistory().length, gameState);

            if (ev.hasEnPassantVictim)
                pieceRenderer.animateMove(ev.move.fromRow, ev.move.fromCol, ev.move.toRow, ev.move.toCol, ev.pieceId, finishEngineAnim,
                    ev.enPassantVictimRow, ev.enPassantVictimCol);
            else
                pieceRenderer.animateMove(ev.move.fromRow, ev.move.fromCol, ev.move.toRow, ev.move.toCol, ev.pieceId, finishEngineAnim);
        }
    }
}
