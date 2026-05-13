package pieces;

import interfaces.IPiece;
import config.PieceCatalog;
import engine.Zobrist;

/**
 * Creates piece instances. All concrete types are registered in `config.PieceCatalog` (single source of truth).
 */
class PieceFactory {
    private static var pieceConstructors:Map<String, String->IPiece> = new Map();

    public static function registerPieceType(type:String, constructor:String->IPiece):Void {
        pieceConstructors.set(type, constructor);
    }

    public static function init():Void {
        pieceConstructors = new Map();
        PieceCatalog.rebuild(true);
        for (e in PieceCatalog.definitions())
            registerPieceType(e.id, e.factory);
        Zobrist.invalidate();
    }

    public static function createPiece(id:String):IPiece {
        if (id == "")
            return null;

        var parsed = utils.BoardUtils.parsePieceId(id);
        var type = parsed.type;
        var color = parsed.color;

        if (pieceConstructors.exists(type))
            return pieceConstructors.get(type)(color);

        return new BasePiece(type, color);
    }

    public static function createPieceByType(type:String, color:String):IPiece {
        if (pieceConstructors.exists(type))
            return pieceConstructors.get(type)(color);
        return new BasePiece(type, color);
    }
}
