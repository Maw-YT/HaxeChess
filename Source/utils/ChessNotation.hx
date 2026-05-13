package utils;

import openfl.geom.Point;
import config.GameConfig;

/**
 * Utility class for chess notation conversions
 * Handles UCI notation, algebraic notation, and coordinate conversions
 */
class ChessNotation {
    
    /**
     * Convert board coordinates to UCI move notation
     * e.g., fromCol=4, fromRow=6, toCol=4, toRow=4 -> "e2e4"
     */
    public static function toUCI(fromCol:Int, fromRow:Int, toCol:Int, toRow:Int, ?promotion:String = ""):String {
        var fromFile = colToFile(fromCol);
        var fromRank = rowToRank(fromRow);
        var toFile = colToFile(toCol);
        var toRank = rowToRank(toRow);
        
        return fromFile + fromRank + toFile + toRank + promotion;
    }
    
    /**
     * Parse a UCI move string to coordinates
     * e.g., "e2e4" -> {fromCol:4, fromRow:6, toCol:4, toRow:4}
     */
    public static function parseUCI(move:String):MoveCoords {
        if (move == null || move.length < 4) return null;
        var re = ~/^([a-z])([0-9]+)([a-z])([0-9]+)([a-z]?)$/i;
        if (!re.match(move))
            return null;

        var fromCol = fileToCol(re.matched(1).toLowerCase());
        var fromRank = re.matched(2);
        var toCol = fileToCol(re.matched(3).toLowerCase());
        var toRank = re.matched(4);
        var promo = re.matched(5);

        var result:MoveCoords = {
            fromCol: fromCol,
            fromRow: rankToRow(fromRank),
            toCol: toCol,
            toRow: rankToRow(toRank),
            promotion: promo != null ? promo.toLowerCase() : ""
        };
        
        return result;
    }
    
    /**
     * Convert column index to file letter (0=a, 1=b, ..., 7=h)
     */
    public static function colToFile(col:Int):String {
        return String.fromCharCode("a".code + col);
    }
    
    /**
     * Convert file letter to column index
     */
    public static function fileToCol(file:String):Int {
        return file.charCodeAt(0) - "a".code;
    }
    
    /**
     * Convert row index to rank number (0=8, 1=7, ..., 7=1 for white at bottom)
     */
    public static function rowToRank(row:Int):String {
        return Std.string(GameConfig.boardRows - row);
    }
    
    /**
     * Convert rank number to row index
     */
    public static function rankToRow(rank:String):Int {
        return GameConfig.boardRows - Std.parseInt(rank);
    }
    
    /**
     * Convert Point to algebraic notation square
     */
    public static function pointToSquare(point:Point):String {
        return colToFile(Std.int(point.x)) + rowToRank(Std.int(point.y));
    }
    
    /**
     * Convert algebraic square to Point
     */
    public static function squareToPoint(square:String):Point {
        if (square == null || square.length < 2)
            return new Point(0, 0);
        var file = square.charAt(0);
        var rank = square.substr(1);
        return new Point(fileToCol(file), rankToRow(rank));
    }
    
    /**
     * Get piece type for promotion notation
     * UCI uses lowercase: q, r, b, n
     */
    public static function promotionToUCI(pieceType:String):String {
        if (pieceType == null) return "";
        
        return switch (pieceType.toLowerCase()) {
            case "queen", "q": "q";
            case "rook", "r": "r";
            case "bishop", "b": "b";
            case "knight", "n": "n";
            default: "";
        }
    }
    
    /**
     * Get piece type from UCI promotion character
     */
    public static function uciToPromotion(uci:String):String {
        return switch (uci.toLowerCase()) {
            case "q": "queen";
            case "r": "rook";
            case "b": "bishop";
            case "n": "knight";
            default: "";
        }
    }
}

/**
 * Typedef for move coordinates
 */
typedef MoveCoords = {
    var fromCol:Int;
    var fromRow:Int;
    var toCol:Int;
    var toRow:Int;
    var promotion:String;
}