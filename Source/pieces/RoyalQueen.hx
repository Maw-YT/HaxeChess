package pieces;

import openfl.geom.Point;

/**
 * RoyalQueen: A queen with royal status (game ends if captured)
 * Moves like a normal queen (rook + bishop combined)
 * But is marked as royal like a King
 */
class RoyalQueen extends BasePiece {
    public function new(color:String) {
        super("royalqueen", color);
        setRoyal(true);
    }
    
    override public function getValidMoves(currentRow:Int, currentCol:Int, board:Array<Array<String>>):Array<Point> {
        var dirs = [
            {r: 1, c: 0}, {r: -1, c: 0}, {r: 0, c: 1}, {r: 0, c: -1}, // Rook moves
            {r: 1, c: 1}, {r: 1, c: -1}, {r: -1, c: 1}, {r: -1, c: -1} // Bishop moves
        ];
        return getSlidingMoves(currentRow, currentCol, dirs, board);
    }
}
