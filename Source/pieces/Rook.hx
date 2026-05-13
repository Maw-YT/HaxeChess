package pieces;

import openfl.geom.Point;

/**
 * Rook: Horizontal and vertical sliding piece
 */
class Rook extends BasePiece {
    public function new(color:String) {
        super("rook", color);
    }
    
    override public function getValidMoves(currentRow:Int, currentCol:Int, board:Array<Array<String>>):Array<Point> {
        var dirs = [
            {r: 1, c: 0}, {r: -1, c: 0}, 
            {r: 0, c: 1}, {r: 0, c: -1}
        ];
        return getSlidingMoves(currentRow, currentCol, dirs, board);
    }
}