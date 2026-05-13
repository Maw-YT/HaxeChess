package pieces;

import openfl.geom.Point;

/**
 * Queen: Combines rook and bishop movement
 */
class Queen extends BasePiece {
    public function new(color:String) {
        super("queen", color);
    }
    
    override public function getValidMoves(currentRow:Int, currentCol:Int, board:Array<Array<String>>):Array<Point> {
        var dirs = [
            {r: 1, c: 0}, {r: -1, c: 0}, {r: 0, c: 1}, {r: 0, c: -1}, // Rook moves
            {r: 1, c: 1}, {r: 1, c: -1}, {r: -1, c: 1}, {r: -1, c: -1} // Bishop moves
        ];
        return getSlidingMoves(currentRow, currentCol, dirs, board);
    }
}