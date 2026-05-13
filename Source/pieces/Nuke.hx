package pieces;

import openfl.geom.Point;
import utils.MoveUtils;

/** Nuke: queen + nightrider (combines queen moves with repeated knight leaps). */
class Nuke extends BasePiece {
    public function new(color:String) {
        super("nuke", color);
    }

    override public function getValidMoves(currentRow:Int, currentCol:Int, board:Array<Array<String>>):Array<Point> {
        var dirs = [
            {r: 1, c: 0}, {r: -1, c: 0}, {r: 0, c: 1}, {r: 0, c: -1},
            {r: 1, c: 1}, {r: 1, c: -1}, {r: -1, c: 1}, {r: -1, c: -1}
        ];
        var q = getSlidingMoves(currentRow, currentCol, dirs, board);
        var n = MoveUtils.getKnightRiderMoves(currentRow, currentCol, board, getColor());
        return MoveUtils.mergeUniquePoints(q, n);
    }
}
