package pieces;

import openfl.geom.Point;

/**
 * Royal knight: moves as a knight and is royal (check / checkmate / game end like a king).
 * Does not castle.
 */
class RoyalKnight extends BasePiece {
    public function new(color:String) {
        super("royalknight", color);
        setRoyal(true);
    }

    override public function getValidMoves(currentRow:Int, currentCol:Int, board:Array<Array<String>>):Array<Point> {
        var offsets = [
            {r: 2, c: 1}, {r: 2, c: -1}, {r: -2, c: 1}, {r: -2, c: -1},
            {r: 1, c: 2}, {r: 1, c: -2}, {r: -1, c: 2}, {r: -1, c: -2}
        ];
        return getStepMoves(currentRow, currentCol, offsets, board);
    }
}
