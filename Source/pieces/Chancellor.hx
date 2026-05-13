package pieces;

import openfl.geom.Point;
import utils.MoveUtils;

/** Chancellor (Marshall): rook + knight. */
class Chancellor extends BasePiece {
    public function new(color:String) {
        super("chancellor", color);
    }

    override public function getValidMoves(currentRow:Int, currentCol:Int, board:Array<Array<String>>):Array<Point> {
        var rDirs = [{r: 1, c: 0}, {r: -1, c: 0}, {r: 0, c: 1}, {r: 0, c: -1}];
        var r = getSlidingMoves(currentRow, currentCol, rDirs, board);
        var nOff = [
            {r: 2, c: 1}, {r: 2, c: -1}, {r: -2, c: 1}, {r: -2, c: -1},
            {r: 1, c: 2}, {r: 1, c: -2}, {r: -1, c: 2}, {r: -1, c: -2}
        ];
        var n = getStepMoves(currentRow, currentCol, nOff, board);
        return MoveUtils.mergeUniquePoints(r, n);
    }
}
