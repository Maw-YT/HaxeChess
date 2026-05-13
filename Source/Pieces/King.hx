package pieces;

import openfl.geom.Point;
import managers.CastlingManager;
import managers.ValidationManager;

/**
 * King: One square in any direction, plus castling
 */
class King extends BasePiece {
    public function new(color:String) {
        super("king", color);
        setRoyal(true);
    }
    
    override public function getValidMoves(currentRow:Int, currentCol:Int, board:Array<Array<String>>):Array<Point> {
        var moves:Array<Point> = [];

        // Regular one-square moves in all 8 directions
        var offsets = [];
        for (dr in -1...2) {
            for (dc in -1...2) {
                if (dr == 0 && dc == 0) continue;
                offsets.push({r: dr, c: dc});
            }
        }
        moves = getStepMoves(currentRow, currentCol, offsets, board);

        // Add castling moves - but only when NOT already validating to prevent infinite recursion
        // The isValidating flag is set during move validation to prevent infinite recursion
        if (!ValidationManager.isValidating && CastlingManager.instance != null) {
            var castlingMoves = CastlingManager.instance.getCastlingMoves(getColor(), board, currentCol);
            moves = moves.concat(castlingMoves);
        }
        
        return moves;
    }
}