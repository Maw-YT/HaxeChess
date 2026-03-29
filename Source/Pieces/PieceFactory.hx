package pieces;

import interfaces.IPiece;

/**
 * Factory for creating piece instances
 * Makes it easy to add new piece types
 */
class PieceFactory {
    private static var pieceConstructors:Map<String, String->IPiece> = new Map();
    
    /**
     * Register a new piece type constructor
     * Call this to add custom piece types
     */
    public static function registerPieceType(type:String, constructor:String->IPiece):Void {
        pieceConstructors.set(type, constructor);
    }
    
    /**
     * Initialize default piece types
     */
    public static function init():Void {
        // Register all standard chess pieces
        registerPieceType("pawn", function(color:String):IPiece return new Pawn(color));
        registerPieceType("rook", function(color:String):IPiece return new Rook(color));
        registerPieceType("knight", function(color:String):IPiece return new Knight(color));
        registerPieceType("bishop", function(color:String):IPiece return new Bishop(color));
        registerPieceType("queen", function(color:String):IPiece return new Queen(color));
        registerPieceType("king", function(color:String):IPiece return new King(color));
        registerPieceType("nuke", function(color:String):IPiece return new Nuke(color));
    }
    
    /**
     * Create a piece from its ID string (e.g., "pawn-w")
     */
    public static function createPiece(id:String):IPiece {
        if (id == "") return null;
        
        var parsed = utils.BoardUtils.parsePieceId(id);
        var type = parsed.type;
        var color = parsed.color;
        
        if (pieceConstructors.exists(type)) {
            return pieceConstructors.get(type)(color);
        }
        
        // Default to generic piece if type not found
        return new BasePiece(type, color);
    }
    
    /**
     * Create a piece by type and color
     */
    public static function createPieceByType(type:String, color:String):IPiece {
        if (pieceConstructors.exists(type)) {
            return pieceConstructors.get(type)(color);
        }
        return new BasePiece(type, color);
    }
}