package managers;

import openfl.geom.Point;
import utils.BoardUtils;
import managers.ValidationManager;

/**
 * Manages castling rules and tracking
 * Tracks which pieces have moved to determine castling eligibility
 */
class CastlingManager {
    private var whiteKingMoved:Bool = false;
    private var blackKingMoved:Bool = false;
    private var whiteRookAMoved:Bool = false; // Queenside rook (a-file, column 0)
    private var whiteRookHMoved:Bool = false; // Kingside rook (h-file, column 7)
    private var blackRookAMoved:Bool = false;
    private var blackRookHMoved:Bool = false;

    public static var instance:CastlingManager;
    
    public function new() {
        instance = this;
    }
    
    /**
     * Check if castling is available for a specific color and side
     * side: "kingside" or "queenside"
     */
    public function canCastle(color:String, side:String, board:Array<Array<String>>):Bool {
        if (!config.GameConfig.CASTLING_ENABLED) return false;
        
        var kingRow = (color == "w") ? 7 : 0;
        var kingMoved = (color == "w") ? whiteKingMoved : blackKingMoved;
        
        // Check if king has moved
        if (kingMoved) return false;
        
        // Verify king is actually on the board at its starting position
        if (board[kingRow][4] != "king-" + color) return false;
        
        // Check if king is currently in check
        if (ValidationManager.isCheck(color, board)) return false;
        
        if (side == "kingside") {
            var rookMoved = (color == "w") ? whiteRookHMoved : blackRookHMoved;
            if (rookMoved) return false;
            
            // Verify rook is on the board at kingside
            if (board[kingRow][7] != "rook-" + color) return false;
            
            // Check path is clear (columns 5 and 6 must be empty)
            if (board[kingRow][5] != "" || board[kingRow][6] != "") return false;
            
            // Check that king doesn't pass through check at f1/f8
            var testBoard1 = BoardUtils.copyBoard(board);
            testBoard1[kingRow][5] = "king-" + color;
            testBoard1[kingRow][4] = "";
            if (ValidationManager.isCheck(color, testBoard1)) return false;
            
            // Check that king doesn't land in check at g1/g8
            var testBoard2 = BoardUtils.copyBoard(board);
            testBoard2[kingRow][6] = "king-" + color;
            testBoard2[kingRow][4] = "";
            if (ValidationManager.isCheck(color, testBoard2)) return false;
            
            return true;
        } else {
            var rookMoved = (color == "w") ? whiteRookAMoved : blackRookAMoved;
            if (rookMoved) return false;
            
            // Verify rook is on the board at queenside
            if (board[kingRow][0] != "rook-" + color) return false;
            
            // Check path is clear (columns 1, 2, 3 must be empty)
            if (board[kingRow][1] != "" || board[kingRow][2] != "" || board[kingRow][3] != "") return false;
            
            // Check that king doesn't pass through check at d1/d8
            var testBoard1 = BoardUtils.copyBoard(board);
            testBoard1[kingRow][3] = "king-" + color;
            testBoard1[kingRow][4] = "";
            if (ValidationManager.isCheck(color, testBoard1)) return false;
            
            // Check that king doesn't land in check at c1/c8
            var testBoard2 = BoardUtils.copyBoard(board);
            testBoard2[kingRow][2] = "king-" + color;
            testBoard2[kingRow][4] = "";
            if (ValidationManager.isCheck(color, testBoard2)) return false;
            
            return true;
        }
    }
    
    /**
     * Get all possible castling moves for a color
     */
    public function getCastlingMoves(color:String, board:Array<Array<String>>):Array<Point> {
        var moves:Array<Point> = [];
        var kingRow = (color == "w") ? 7 : 0;
        
        if (canCastle(color, "kingside", board)) {
            moves.push(new Point(6, kingRow)); // King moves to g-file
        }
        if (canCastle(color, "queenside", board)) {
            moves.push(new Point(2, kingRow)); // King moves to c-file
        }
        
        return moves;
    }
    
    /**
     * Execute castling move on the board
     */
    public function executeCastling(color:String, side:String, board:Array<Array<String>>):Void {
        var kingRow = (color == "w") ? 7 : 0;
        
        if (side == "kingside") {
            // Move king from e-file (4) to g-file (6)
            board[kingRow][6] = "king-" + color;
            board[kingRow][4] = "";
            // Move rook from h-file (7) to f-file (5)
            board[kingRow][5] = "rook-" + color;
            board[kingRow][7] = "";
        } else {
            // Move king from e-file (4) to c-file (2)
            board[kingRow][2] = "king-" + color;
            board[kingRow][4] = "";
            // Move rook from a-file (0) to d-file (3)
            board[kingRow][3] = "rook-" + color;
            board[kingRow][0] = "";
        }
        
        // Mark king and rook as moved
        if (color == "w") {
            whiteKingMoved = true;
            if (side == "kingside") whiteRookHMoved = true;
            else whiteRookAMoved = true;
        } else {
            blackKingMoved = true;
            if (side == "kingside") blackRookHMoved = true;
            else blackRookAMoved = true;
        }
    }
    
    /**
     * Mark that a piece has moved (revokes castling rights)
     */
    public function markPieceMoved(pieceId:String, col:Int, row:Int):Void {
        var parsed = BoardUtils.parsePieceId(pieceId);
        
        if (parsed.type == "king") {
            if (parsed.color == "w") whiteKingMoved = true;
            else blackKingMoved = true;
        } else if (parsed.type == "rook") {
            if (parsed.color == "w") {
                if (col == 0) whiteRookAMoved = true;
                if (col == 7) whiteRookHMoved = true;
            } else {
                if (col == 0) blackRookAMoved = true;
                if (col == 7) blackRookHMoved = true;
            }
        }
    }
}