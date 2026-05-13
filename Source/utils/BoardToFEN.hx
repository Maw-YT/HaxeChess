package utils;

/**
 * Utility class to convert board state to FEN notation
 * FEN: Forsyth-Edwards Notation
 */
class BoardToFEN {
    static var typeToFenLower:Map<String, String> = new Map();
    static var fenLowerToType:Map<String, String> = new Map();
    static var typeToEngineFenLower:Map<String, String> = new Map();

    /**
     * Called from `PieceCatalog.install()` after rebuilding piece definitions.
     */
    public static function refreshPieceFenTables(
        typeToFen:Map<String, String>,
        fenToType:Map<String, String>,
        typeToEngine:Map<String, String>
    ):Void {
        typeToFenLower = typeToFen;
        fenLowerToType = fenToType;
        typeToEngineFenLower = typeToEngine;
    }

    /**
     * Convert board data to FEN string
     * @param boardData 8x8 array of piece strings
     * @param currentTurn "w" or "b"
     * @param castlingRights Castling availability string (e.g., "KQkq")
     * @param enPassant En passant target square or "-"
     * @param halfmoveClock Moves since last capture or pawn advance
     * @param fullmoveNumber Current move number
     */
    public static function toFEN(boardData:Array<Array<String>>, currentTurn:String = "w",
                                  castlingRights:String = "KQkq", enPassant:String = "-",
                                  halfmoveClock:Int = 0, fullmoveNumber:Int = 1):String {
        
        var fenParts:Array<String> = [];
        
        // 1. Piece placement
        fenParts.push(getPiecePlacement(boardData));
        
        // 2. Active color
        fenParts.push(currentTurn);
        
        // 3. Castling availability
        fenParts.push(castlingRights != "" ? castlingRights : "-");
        
        // 4. En passant target square
        fenParts.push(enPassant);
        
        // 5. Halfmove clock
        fenParts.push(Std.string(halfmoveClock));
        
        // 6. Fullmove number
        fenParts.push(Std.string(fullmoveNumber));
        
        return fenParts.join(" ");
    }
    
    /**
     * Get piece placement part of FEN (public for repetition keys and tools).
     */
    public static function getPiecePlacement(boardData:Array<Array<String>>):String {
        var rows:Array<String> = [];
        var br = boardData.length;
        for (row in 0...br) {
            var rowStr = "";
            var emptyCount = 0;
            var bc = boardData[row].length;
            for (col in 0...bc) {
                var piece = boardData[row][col];
                
                if (piece == null || piece == "") {
                    emptyCount++;
                } else {
                    if (emptyCount > 0) {
                        rowStr += Std.string(emptyCount);
                        emptyCount = 0;
                    }
                    rowStr += pieceToFEN(piece);
                }
            }
            
            if (emptyCount > 0) {
                rowStr += Std.string(emptyCount);
            }
            
            rows.push(rowStr);
        }
        
        return rows.join("/");
    }

    /**
     * Engine placement for custom Royal Pawn engines.
     * Royal Pawn is encoded as 's'/'S' as requested by the custom engine.
     */
    public static function getEnginePiecePlacement(boardData:Array<Array<String>>):String {
        var rows:Array<String> = [];
        var br = boardData.length;
        for (row in 0...br) {
            var rowStr = "";
            var emptyCount = 0;
            var bc = boardData[row].length;
            for (col in 0...bc) {
                var piece = boardData[row][col];
                if (piece == null || piece == "") {
                    emptyCount++;
                    continue;
                }
                if (emptyCount > 0) {
                    rowStr += Std.string(emptyCount);
                    emptyCount = 0;
                }

                rowStr += pieceToEngineFEN(piece);
            }
            if (emptyCount > 0)
                rowStr += Std.string(emptyCount);
            rows.push(rowStr);
        }

        return rows.join("/");
    }
    
    /**
     * Convert piece string to FEN character
     * Capital letters for white, lowercase for black
     */
    private static function pieceToFEN(piece:String):String {
        if (piece == null || piece.length == 0) return "";

        var parsed = BoardUtils.parsePieceId(piece);
        var basePiece = parsed.type;
        var isWhite = parsed.color == "w";

        var fenChar = typeToFenLower.get(basePiece);
        if (fenChar == null || fenChar == "")
            return "";

        if (isWhite)
            return fenChar.toUpperCase();
        return fenChar;
    }

    private static function pieceToEngineFEN(piece:String):String {
        if (piece == null || piece.length == 0) return "";
        var parsed = BoardUtils.parsePieceId(piece);
        var low = typeToEngineFenLower.get(parsed.type);
        if (low == null || low == "")
            return pieceToFEN(piece);
        return parsed.color == "w" ? low.toUpperCase() : low;
    }
    
    /**
     * Get starting position FEN
     */
    public static function startingFEN():String {
        return "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";
    }
    
    /**
     * Parse FEN string to board data
     */
    public static function fromFEN(fen:String):Array<Array<String>> {
        var parts = fen.split(" ");
        var rowStrs = parts[0].split("/");
        function rowCellCount(rs:String):Int {
            var w = 0;
            for (i in 0...rs.length) {
                var ch = rs.charAt(i);
                var d = Std.parseInt(ch);
                w += (d > 0 && d <= 8) ? d : 1;
            }
            return w;
        }
        var br = rowStrs.length;
        var bc = 0;
        for (rs in rowStrs) {
            var rw = rowCellCount(rs);
            if (rw > bc)
                bc = rw;
        }
        if (br < 1 || bc < 1) {
            br = 8;
            bc = 8;
        }

        var board:Array<Array<String>> = [for (_ in 0...br) [for (_ in 0...bc) ""]];

        for (row in 0...br) {
            var col = 0;
            for (i in 0...rowStrs[row].length) {
                var c = rowStrs[row].charAt(i);
                var d = Std.parseInt(c);
                if (d > 0 && d <= 8) {
                    col += d;
                } else {
                    var piece = fenToPiece(c);
                    if (col < bc)
                        board[row][col] = piece;
                    col++;
                }
            }
        }

        return board;
    }
    
    /**
     * Convert FEN character to piece string
     */
    private static function fenToPiece(fenChar:String):String {
        var isWhite = fenChar == fenChar.toUpperCase();
        var pieceChar = fenChar.toLowerCase();
        
        var basePiece = fenLowerToType.get(pieceChar);
        if (basePiece != null && basePiece != "")
            return basePiece + (isWhite ? "w" : "b");
        return "";
    }

        /**
     * Get halfmove clock (moves since last capture/pawn advance)
     */
    public static function getHalfmoveClock(boardData:Array<Array<String>>):Int {
        // Simplified - just return 0 for now
        // In a full implementation, you'd track this properly
        return 0;
    }
    
    /**
     * Get fullmove number (starts at 1, increments after black's move)
     */
    public static function getFullmoveNumber(currentTurn:String, moveCount:Int):Int {
        return Math.ceil(moveCount / 2) + 1;
    }
}
