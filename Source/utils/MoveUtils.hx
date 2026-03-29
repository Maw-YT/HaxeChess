package utils;

import openfl.geom.Point;

/**
 * Utility functions for move calculations
 */
class MoveUtils {
    /**
     * Get sliding moves in the specified directions
     * Used by rooks, bishops, queens, and similar pieces
     */
    public static function getSlidingMoves(startRow:Int, startCol:Int, dirs:Array<{r:Int, c:Int}>, board:Array<Array<String>>, color:String):Array<Point> {
        var moves:Array<Point> = [];
        
        for (dir in dirs) {
            var nr = startRow + dir.r;
            var nc = startCol + dir.c;
            
            while (BoardUtils.isValidPosition(nr, nc)) {
                if (BoardUtils.isPositionEmpty(board, nr, nc)) {
                    moves.push(new Point(nc, nr));
                } else {
                    // Can capture enemy piece, but can't go further
                    if (BoardUtils.isEnemyPiece(board, nr, nc, color)) {
                        moves.push(new Point(nc, nr));
                    }
                    break;
                }
                nr += dir.r;
                nc += dir.c;
            }
        }
        
        return moves;
    }
    
    /**
     * Get step moves (single square movements)
     * Used by king, knight, and similar pieces
     */
    public static function getStepMoves(startRow:Int, startCol:Int, offsets:Array<{r:Int, c:Int}>, board:Array<Array<String>>, color:String):Array<Point> {
        var moves:Array<Point> = [];
        
        for (off in offsets) {
            var nr = startRow + off.r;
            var nc = startCol + off.c;
            
            if (BoardUtils.isValidPosition(nr, nc)) {
                if (BoardUtils.isPositionEmpty(board, nr, nc) || BoardUtils.isEnemyPiece(board, nr, nc, color)) {
                    moves.push(new Point(nc, nr));
                }
            }
        }
        
        return moves;
    }
    
    /**
     * Check if a move exists in a list of moves
     */
    public static function hasMove(moves:Array<Point>, target:Point):Bool {
        for (m in moves) {
            if (m.x == target.x && m.y == target.y) {
                return true;
            }
        }
        return false;
    }
    
    /**
     * Get the direction from one position to another
     */
    public static function getDirection(from:Point, to:Point):{r:Int, c:Int} {
        var dr = to.y - from.y;
        var dc = to.x - from.x;
        
        // Normalize to -1, 0, or 1
        var rDir = dr == 0 ? 0 : (dr > 0 ? 1 : -1);
        var cDir = dc == 0 ? 0 : (dc > 0 ? 1 : -1);
        
        return {r: rDir, c: cDir};
    }
}