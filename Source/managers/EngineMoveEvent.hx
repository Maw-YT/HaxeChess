package managers;

import openfl.events.Event;
import utils.ChessNotation.MoveCoords;

/**
 * Dispatched after the engine applies a UCI move; carries pre-move board for animation.
 */
class EngineMoveEvent extends Event {
    public var boardBefore:Array<Array<String>>;
    public var move:MoveCoords;
    public var pieceId:String;
    public var applied:Bool;
    public var isCastling:Bool;
    /** If en passant, square of the captured pawn (before the move). */
    public var enPassantVictimRow:Int;
    public var enPassantVictimCol:Int;
    public var hasEnPassantVictim:Bool;

    public function new(type:String, boardBefore:Array<Array<String>>, move:MoveCoords, pieceId:String, applied:Bool, isCastling:Bool,
            hasEP:Bool, epVR:Int, epVC:Int) {
        super(type, false, false);
        this.boardBefore = boardBefore;
        this.move = move;
        this.pieceId = pieceId;
        this.applied = applied;
        this.isCastling = isCastling;
        this.hasEnPassantVictim = hasEP;
        this.enPassantVictimRow = epVR;
        this.enPassantVictimCol = epVC;
    }
}
