package utils;

import openfl.geom.Point;
import config.GameConfig;

/**
 * Utility functions for board operations
 */
class BoardUtils {
    /**
     * Check if a position is within the board boundaries
     */
    public static function isValidPosition(row:Int, col:Int):Bool {
        return row >= 0 && row < GameConfig.boardRows && col >= 0 && col < GameConfig.boardCols;
    }
    
    /**
     * Parse a piece ID into its type and color
     */
    public static function parsePieceId(id:String):{type:String, color:String} {
        if (id == "") return {type: "", color: ""};
        var parts = id.split("-");
        return {type: parts[0], color: parts.length > 1 ? parts[1] : ""};
    }

    /** Null if row/col out of bounds or row array missing (null reference safe). */
    public static function cellAt(board:Array<Array<String>>, row:Int, col:Int):Null<String> {
        if (board == null || row < 0 || row >= board.length)
            return null;
        var r = board[row];
        if (r == null || col < 0 || col >= r.length)
            return null;
        return r[col];
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
        if (board == null)
            return [];
        return [for (row in board) row != null ? [for (cell in row) cell] : []];
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

    /** Number of squares occupied by that color (any piece type). */
    public static function countPiecesOfColor(board:Array<Array<String>>, color:String):Int {
        return findPiecesOfColor(board, color).length;
    }

    /**
     * Check whether a piece on the given square is protected by a shield aura.
     * A shield protects all adjacent pieces except other shields.
     */
    public static function isSquareProtectedByShield(row:Int, col:Int, board:Array<Array<String>>):Bool {
        if (board == null || !isValidPosition(row, col))
            return false;

        var targetId = cellAt(board, row, col);
        if (targetId == null || targetId == "")
            return false;

        var targetParsed = parsePieceId(targetId);
        if (targetParsed.type == "shield")
            return false;

        for (dr in -1...2) {
            for (dc in -1...2) {
                if (dr == 0 && dc == 0)
                    continue;
                var nr = row + dr;
                var nc = col + dc;
                if (!isValidPosition(nr, nc))
                    continue;
                var neighbor = cellAt(board, nr, nc);
                if (neighbor != null && neighbor != "") {
                    var parsed = parsePieceId(neighbor);
                    if (parsed.type == "shield")
                        return true;
                }
            }
        }

        return false;
    }

    /**
     * Find a royal piece of a specific color
     * Returns the first royal piece found (any piece with isRoyal() == true)
     */
    public static function findRoyalPiece(board:Array<Array<String>>, color:String):Point {
        for (r in 0...board.length) {
            for (c in 0...board[r].length) {
                var pieceId = board[r][c];
                if (pieceId != "" && isPieceOfColor(pieceId, color)) {
                    // Create piece to check if it's royal
                    var piece = pieces.PieceFactory.createPiece(pieceId);
                    if (piece != null && piece.isRoyal()) {
                        return new Point(c, r);
                    }
                }
            }
        }
        return null;
    }
    
    /**
     * Find all royal pieces of a specific color
     * Used when multiple royal pieces could be checkmated
     */
    public static function findAllRoyalPieces(board:Array<Array<String>>, color:String):Array<Point> {
        var royalPieces:Array<Point> = [];
        if (board == null)
            return royalPieces;
        for (r in 0...board.length) {
            var row = board[r];
            if (row == null)
                continue;
            for (c in 0...row.length) {
                var pieceId = row[c];
                if (pieceId != "" && isPieceOfColor(pieceId, color)) {
                    var piece = pieces.PieceFactory.createPiece(pieceId);
                    if (piece != null && piece.isRoyal()) {
                        royalPieces.push(new Point(c, r));
                    }
                }
            }
        }
        return royalPieces;
    }

    /**
     * If this pawn move is en passant, return the captured pawn's square on boardBefore; else null.
     */
    public static function enPassantCaptureSquare(boardBefore:Array<Array<String>>, fromC:Int, fromR:Int, toC:Int, toR:Int,
            movingPieceId:String):Point {
        if (movingPieceId == "")
            return null;
        var mover = parsePieceId(movingPieceId);
        if (mover.type != "pawn" && mover.type != "royalpawn")
            return null;
        if (boardBefore[toR][toC] != "")
            return null;
        if (fromC == toC)
            return null;
        var victim = boardBefore[fromR][toC];
        if (victim == "")
            return null;
        var vp = parsePieceId(victim);
        if (vp.type != "pawn" && vp.type != "royalpawn")
            return null;
        return new Point(toC, fromR);
    }
}