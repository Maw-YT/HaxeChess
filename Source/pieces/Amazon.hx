package pieces;

import openfl.geom.Point;
import utils.MoveUtils;

/** Amazon: queen + knight (common fairy compound). */
class Amazon extends BasePiece {
    public function new(color:String) {
        super("amazon", color);
    }

    override public function getValidMoves(currentRow:Int, currentCol:Int, board:Array<Array<String>>):Array<Point> {
        var dirs = [
            {r: 1, c: 0}, {r: -1, c: 0}, {r: 0, c: 1}, {r: 0, c: -1},
            {r: 1, c: 1}, {r: 1, c: -1}, {r: -1, c: 1}, {r: -1, c: -1}
        ];
        var q = getSlidingMoves(currentRow, currentCol, dirs, board);
        var nOff = [
            {r: 2, c: 1}, {r: 2, c: -1}, {r: -2, c: 1}, {r: -2, c: -1},
            {r: 1, c: 2}, {r: 1, c: -2}, {r: -1, c: 2}, {r: -1, c: -2}
        ];
        var n = getStepMoves(currentRow, currentCol, nOff, board);
        return MoveUtils.mergeUniquePoints(q, n);
    }
}
