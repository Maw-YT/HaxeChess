package config;

/**
 * Central configuration for the game
 * Makes it easy to tweak game parameters without changing code logic
 */
class GameConfig {
    /** Board height in squares (synced from active layout). */
    public static var boardRows:Int = 8;
    /** Board width in squares (synced from active layout). */
    public static var boardCols:Int = 8;

    public static function syncFromBoard(board:Array<Array<String>>):Void {
        if (board == null || board.length == 0) {
            boardRows = 8;
            boardCols = 8;
            return;
        }
        boardRows = board.length;
        var row0 = board[0];
        boardCols = (row0 != null) ? row0.length : 8;
    }

    /** Orthodox 8×8: UCI engines and current castling logic apply. */
    public static function isStandardChessBoard():Bool {
        return boardRows == 8 && boardCols == 8;
    }
    public static inline var DEFAULT_TILE_SIZE:Int = 80;
    /** Upper bound when sizing the board from the window (prevents absurdly huge tiles on 4K). */
    public static inline var MAX_TILE_SIZE:Int = 120;
    public static inline var ANIMATION_DURATION:Float = 0.2;
    /** Piece fade-in / settle when appearing on a square (full board render, promotion, etc.). */
    public static inline var PIECE_SPAWN_DURATION:Float = 0.18;
    /** Piece fade-out when captured or replaced (runs before mover tween on captures). */
    public static inline var PIECE_DEATH_DURATION:Float = 0.22;
    
    // Tile colors
    public static inline var COLOR_LIGHT:Int = 0xEEEEEE;
    public static inline var COLOR_DARK:Int = 0x769656;
    public static inline var COLOR_SELECTED:Int = 0xFFA500;
    /** Last move: from square (contrasts on light/dark boards). */
    public static inline var COLOR_LAST_MOVE_FROM:Int = 0x7EB8E8;
    /** Last move: to square */
    public static inline var COLOR_LAST_MOVE_TO:Int = 0x5A9FD4;
    public static inline var COLOR_HINT:Int = 0xBBCB44;

    // Status colors for game state display
    public static inline var COLOR_CHECK:Int = 0xFF6600;
    public static inline var COLOR_CHECKMATE:Int = 0xFF4444;
    public static inline var COLOR_STALEMATE:Int = 0xFFAA00;
    
    // Asset paths
    public static inline var ASSETS_PATH:String = "assets/";
    public static inline var MISSING_ASSET:String = "missing.png";
    
    // Game rules
    public static inline var CASTLING_ENABLED:Bool = true;
    
    /**
     * Piece values for AI / search / `BasePiece` defaults.
     * Populated by `PieceCatalog.install()` from `Source/config/PieceCatalog.hx`.
     */
    public static var PIECE_VALUES:Map<String, Int> = new Map();
}
