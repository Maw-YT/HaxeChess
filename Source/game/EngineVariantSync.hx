package game;

import config.SettingsConfig;
import managers.UCIManager;

/** Keeps UCI variant (chess / royalpawn / doublechess) aligned with the current board. */
class EngineVariantSync {
    public static inline var VARIANT_PATH:String = "C:\\Users\\whymr\\OneDrive\\Desktop\\All\\stockfish\\src\\variants.ini";

    var activeVariant:String = null;

    public function new() {}

    public static function hasRoyalPawnWithoutKing(board:Array<Array<String>>):Bool {
        var hasRoyalPawn = false;
        var hasKing = false;
        for (r in 0...board.length) {
            var row = board[r];
            for (c in 0...row.length) {
                var id = row[c];
                if (id == null || id == "")
                    continue;
                if (id.indexOf("royalpawn-") == 0)
                    hasRoyalPawn = true;
                if (id.indexOf("king-") == 0)
                    hasKing = true;
            }
        }
        return hasRoyalPawn && !hasKing;
    }

    public function syncForBoard(board:Array<Array<String>>, uci:UCIManager, ?force:Bool = false):Void {
        if (!uci.isEngineReady())
            return;
        var shouldUseDoubleChess = SettingsConfig.boardLayoutId == "double_chess_16x12"
            || SettingsConfig.boardLayoutId == "double_chess_16x8";
        var shouldUseRoyalPawn = hasRoyalPawnWithoutKing(board);
        var nextVariant = shouldUseDoubleChess ? "doublechess" : (shouldUseRoyalPawn ? "royalpawn" : "chess");
        if (!force && activeVariant == nextVariant)
            return;

        if (nextVariant == "royalpawn") {
            uci.setOption("VariantPath", VARIANT_PATH);
        }
        uci.setOption("UCI_Variant", nextVariant);
        uci.newGame();
        activeVariant = nextVariant;
    }

    public function resetMode():Void {
        activeVariant = null;
    }
}
