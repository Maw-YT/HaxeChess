package config;

/**
 * Central configuration for the game
 * Makes it easy to tweak game parameters without changing code logic
 */
class GameConfig {
    public static inline var BOARD_SIZE:Int = 8;
    public static inline var DEFAULT_TILE_SIZE:Int = 80;
    public static inline var ANIMATION_DURATION:Float = 0.2;
    
    // Tile colors
    public static inline var COLOR_LIGHT:Int = 0xEEEEEE;
    public static inline var COLOR_DARK:Int = 0x769656;
    public static inline var COLOR_SELECTED:Int = 0xFFA500;
    public static inline var COLOR_HINT:Int = 0xBBCB44;
    
    // Asset paths
    public static inline var ASSETS_PATH:String = "assets/";
    public static inline var MISSING_ASSET:String = "missing.png";
    
    // Game rules
    public static inline var CASTLING_ENABLED:Bool = true;
    
    // Piece values for AI/evaluation
    public static var PIECE_VALUES:Map<String, Int> = [
        "pawn" => 1,
        "knight" => 3,
        "bishop" => 3,
        "rook" => 5,
        "queen" => 9,
        "king" => 1000,
        "nuke" => 25
    ];
}