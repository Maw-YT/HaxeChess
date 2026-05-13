package pieces;

import openfl.geom.Point;

/**
 * RoyalBishop: A bishop with royal status (game ends if captured)
 * Moves like a normal bishop (diagonal movement)
 * But is marked as royal like a King
 */
class RoyalBishop extends BasePiece {
    public function new(color:String) {
        super("royalbishop", color);
        setRoyal(true);
    }
    
    override public function getValidMoves(currentRow:Int, currentCol:Int, board:Array<Array<String>>):Array<Point> {
        var dirs = [
            {r: 1, c: 1}, {r: 1, c: -1}, {r: -1, c: 1}, {r: -1, c: -1}
        ];
        return getSlidingMoves(currentRow, currentCol, dirs, board);
    }
}
