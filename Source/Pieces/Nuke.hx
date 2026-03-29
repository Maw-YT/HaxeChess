package pieces;

import openfl.geom.Point;

/**
 * Nuke: Queen + Super-Knight (Nightrider) sliding
 * A powerful custom piece
 */
class Nuke extends BasePiece {
    public function new(color:String) {
        super("nuke", color);
    }
    
    override public function getValidMoves(currentRow:Int, currentCol:Int, board:Array<Array<String>>):Array<Point> {
        var moves:Array<Point> = [];
        
        // Queen directions
        var queenDirs = [
            {r:1, c:0}, {r:-1, c:0}, {r:0, c:1}, {r:0, c:-1},
            {r:1, c:1}, {r:1, c:-1}, {r:-1, c:1}, {r:-1, c:-1}
        ];
        
        // Super-Knight (Nightrider) sliding directions
        var superKnightDirs = [
            {r:2, c:1}, {r:2, c:-1}, {r:-2, c:1}, {r:-2, c:-1},
            {r:1, c:2}, {r:1, c:-2}, {r:-1, c:2}, {r:-1, c:-2}
        ];
        
        moves = moves.concat(getSlidingMoves(currentRow, currentCol, queenDirs, board));
        moves = moves.concat(getSlidingMoves(currentRow, currentCol, superKnightDirs, board));
        
        return moves;
    }
}