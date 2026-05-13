package config;

/**
 * Shared numeric tags for piece-square routing (`Eval`) and draw heuristics (`DrawRules`).
 * Used by `PieceCatalogEntries` when building each `PieceDef`.
 */
class PieceCatalogMetrics {
    public static inline var PST_PAWN:Int = 0;
    public static inline var PST_KNIGHT:Int = 1;
    public static inline var PST_BISHOP:Int = 2;
    public static inline var PST_ROOK:Int = 3;
    public static inline var PST_QUEEN:Int = 4;
    public static inline var PST_KING_MG:Int = 5;
    public static inline var PST_AMAZON:Int = 6;
    public static inline var PST_CHANCELLOR:Int = 7;
    public static inline var PST_ARCHBISHOP:Int = 8;
    public static inline var PST_GRASSHOPPER:Int = 9;
    public static inline var PST_KNIGHT_LIKE:Int = 10;
    public static inline var PST_FALLBACK:Int = 11;

    public static inline var DRAW_HEAVY:Int = 0;
    public static inline var DRAW_ROYAL_KING:Int = 1;
    public static inline var DRAW_KNIGHT_MINOR:Int = 2;
    public static inline var DRAW_BISHOP:Int = 3;
    public static inline var DRAW_DEFAULT_HEAVY:Int = 4;
}
