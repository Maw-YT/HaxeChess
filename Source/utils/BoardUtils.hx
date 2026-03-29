package utils;

import openfl.geom.Point;

/**
 * Utility functions for board operations
 */
class BoardUtils {
    /**
     * Check if a position is within the board boundaries
     */
    public static function isValidPosition(row:Int, col:Int, size:Int = 8):Bool {
        return row >= 0 && row < size && col >= 0 && col < size;
    }
    
    /**
     * Parse a piece ID into its type and color
     */
    public static function parsePieceId(id:String):{type:String, color:String} {
        if (id == "") return {type: "", color: ""};
        var parts = id.split("-");
        return {type: parts[0], color: parts[1]};
    }
    
    /**
     * Check if a piece belongs to a specific color
     */
    public static function isPieceOfColor(pieceId:String, color:String):Bool {
        var parsed = parsePieceId(pieceId);
        return parsed.color == color;
    }
    
    /**
     * Check if a position is empty on the board
     */
    public static function isPositionEmpty(board:Array<Array<String>>, row:Int, col:Int):Bool {
        return board[row][col] == "";
    }
    
    /**
     * Check if a position contains an enemy piece
     */
    public static function isEnemyPiece(board:Array<Array<String>>, row:Int, col:Int, myColor:String):Bool {
        var pieceId = board[row][col];
        if (pieceId == "") return false;
        return !isPieceOfColor(pieceId, myColor);
    }
    
    /**
     * Create a deep copy of the board data
     */
    public static function copyBoard(board:Array<Array<String>>):Array<Array<String>> {
        return [for (row in board) [for (cell in row) cell]];
    }
    
    /**
     * Find all pieces of a specific color on the board
     */
    public static function findPiecesOfColor(board:Array<Array<String>>, color:String):Array<{row:Int, col:Int, pieceId:String}> {
        var pieces = [];
        for (r in 0...board.length) {
            for (c in 0...board[r].length) {
                if (isPieceOfColor(board[r][c], color)) {
                    pieces.push({row: r, col: c, pieceId: board[r][c]});
                }
            }
        }
        return pieces;
    }
    
    /**
     * Find the royal piece (king) of a specific color
     */
    public static function findRoyalPiece(board:Array<Array<String>>, color:String):Point {
        for (r in 0...board.length) {
            for (c in 0...board[r].length) {
                var parsed = parsePieceId(board[r][c]);
                if (parsed.type == "king" && parsed.color == color) {
                    return new Point(c, r);
                }
            }
        }
        return null;
    }
}