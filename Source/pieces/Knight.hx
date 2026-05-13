package pieces;

import openfl.geom.Point;

/**
 * Knight: L-shaped movement piece
 */
class Knight extends BasePiece {
    public function new(color:String) {
        super("knight", color);
    }
    
    override public function getValidMoves(currentRow:Int, currentCol:Int, board:Array<Array<String>>):Array<Point> {
        var offsets = [
            {r: 2, c: 1}, {r: 2, c: -1}, {r: -2, c: 1}, {r: -2, c: -1},
            {r: 1, c: 2}, {r: 1, c: -2}, {r: -1, c: 2}, {r: -1, c: -2}
        ];
        return getStepMoves(currentRow, currentCol, offsets, board);
    }
}