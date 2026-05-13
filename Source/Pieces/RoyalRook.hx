package pieces;

import openfl.geom.Point;

/**
 * RoyalRook: A rook with royal status (game ends if captured)
 * Moves like a normal rook (horizontal and vertical)
 * But is marked as royal like a King
 */
class RoyalRook extends BasePiece {
    public function new(color:String) {
        super("royalrook", color);
        setRoyal(true);
    }
    
    override public function getValidMoves(currentRow:Int, currentCol:Int, board:Array<Array<String>>):Array<Point> {
        var dirs = [
            {r: 1, c: 0}, {r: -1, c: 0}, {r: 0, c: 1}, {r: 0, c: -1}
        ];
        return getSlidingMoves(currentRow, currentCol, dirs, board);
    }
}
