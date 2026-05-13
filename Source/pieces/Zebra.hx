package pieces;

import openfl.geom.Point;

/** Zebra: (2,3) leaper. */
class Zebra extends BasePiece {
    public function new(color:String) {
        super("zebra", color);
    }

    override public function getValidMoves(currentRow:Int, currentCol:Int, board:Array<Array<String>>):Array<Point> {
        var off = [
            {r: 2, c: 3}, {r: 2, c: -3}, {r: -2, c: 3}, {r: -2, c: -3},
            {r: 3, c: 2}, {r: 3, c: -2}, {r: -3, c: 2}, {r: -3, c: -2}
        ];
        return getStepMoves(currentRow, currentCol, off, board);
    }
}
