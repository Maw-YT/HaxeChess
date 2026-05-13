package game;

/**
 * Strings and keys for the in-board game-over overlay (timeouts, mate, draws).
 */
class GameEndCopy {
    public static function winnerDisplayName(color:String):String {
        return color == "w" ? "White" : "Black";
    }

    public static function isTerminalGameState(gameState:String):Bool {
        return gameState == "checkmate" || gameState == "stalemate" || gameState == "draw_repetition" || gameState == "draw_material"
            || gameState == "draw_no_royals" || gameState == "win_white" || gameState == "win_black";
    }

    public static function overlayDismissKey(gameState:String, timeoutWinner:String):String {
        if (timeoutWinner != "")
            return "timeout:" + timeoutWinner;
        return "state:" + gameState;
    }

    /**
     * @param currentTurnWhenTerminal Side to move in the terminal position (mated side on checkmate).
     */
    public static function buildOverlayCopy(gameState:String, timeoutWinner:String, currentTurnWhenTerminal:String):{
        title:String,
        subtitle:String,
        confetti:Bool
    } {
        if (timeoutWinner != "")
            return { title: "Time out", subtitle: winnerDisplayName(timeoutWinner) + " wins on time", confetti: false };
        return switch (gameState) {
            case "checkmate":
                var mated = currentTurnWhenTerminal;
                var winCol = mated == "w" ? "b" : "w";
                { title: "Checkmate", subtitle: winnerDisplayName(winCol) + " wins", confetti: true };
            case "stalemate":
                { title: "Stalemate", subtitle: "Draw", confetti: false };
            case "draw_repetition":
                { title: "Draw", subtitle: "Threefold repetition", confetti: false };
            case "draw_material":
                { title: "Draw", subtitle: "Insufficient material", confetti: false };
            case "draw_no_royals":
                { title: "Draw", subtitle: "No royal pieces", confetti: false };
            case "win_white":
                { title: "White wins", subtitle: "No opposing royals", confetti: false };
            case "win_black":
                { title: "Black wins", subtitle: "No opposing royals", confetti: false };
            default:
                { title: "Game over", subtitle: "", confetti: false };
        };
    }
}
