package pieces;

import openfl.geom.Point;
import utils.MoveUtils;

/** Archbishop (Cardinal): bishop + knight. */
class Archbishop extends BasePiece {
    public function new(color:String) {
        super("archbishop", color);
    }

    override public function getValidMoves(currentRow:Int, currentCol:Int, board:Array<Array<String>>):Array<Point> {
        var bDirs = [{r: 1, c: 1}, {r: 1, c: -1}, {r: -1, c: 1}, {r: -1, c: -1}];
        var b = getSlidingMoves(currentRow, currentCol, bDirs, board);
        var nOff = [
            {r: 2, c: 1}, {r: 2, c: -1}, {r: -2, c: 1}, {r: -2, c: -1},
            {r: 1, c: 2}, {r: 1, c: -2}, {r: -1, c: 2}, {r: -1, c: -2}
        ];
        var n = getStepMoves(currentRow, currentCol, nOff, board);
        return MoveUtils.mergeUniquePoints(b, n);
    }
}
