package config;

/**
 * Board layout configuration
 * Makes it easy to create different starting positions
 */
class BoardLayout {
    /**
     * Standard chess layout with Nuke pieces
     */
    public static function getStandardLayout():Array<Array<String>> {
        return [
            ["rook-b", "knight-b", "bishop-b", "queen-b", "king-b", "bishop-b", "knight-b", "rook-b"],
            ["pawn-b", "pawn-b", "pawn-b", "pawn-b", "pawn-b", "pawn-b", "pawn-b", "pawn-b"],
            ["", "", "", "", "", "", "nuke-b", ""],
            ["", "", "", "", "", "", "", ""],
            ["", "", "", "", "", "", "", ""],
            ["", "nuke-w", "", "", "", "", "", ""],
            ["pawn-w", "pawn-w", "pawn-w", "pawn-w", "pawn-w", "pawn-w", "pawn-w", "pawn-w"],
            ["rook-w", "knight-w", "bishop-w", "queen-w", "king-w", "bishop-w", "knight-w", "rook-w"]
        ];
    }
    
    /**
     * Pure standard chess (no Nuke pieces)
     */
    public static function getClassicLayout():Array<Array<String>> {
        return [
            ["rook-b", "knight-b", "bishop-b", "queen-b", "king-b", "bishop-b", "knight-b", "rook-b"],
            ["pawn-b", "pawn-b", "pawn-b", "pawn-b", "pawn-b", "pawn-b", "pawn-b", "pawn-b"],
            ["", "", "", "", "", "", "", ""],
            ["", "", "", "", "", "", "", ""],
            ["", "", "", "", "", "", "", ""],
            ["", "", "", "", "", "", "", ""],
            ["pawn-w", "pawn-w", "pawn-w", "pawn-w", "pawn-w", "pawn-w", "pawn-w", "pawn-w"],
            ["rook-w", "knight-w", "bishop-w", "queen-w", "king-w", "bishop-w", "knight-w", "rook-w"]
        ];
    }
    
    /**
     * Custom empty board for puzzles/scenarios
     */
    public static function getEmptyLayout():Array<Array<String>> {
        return [
            for (r in 0...8) [for (c in 0...8) ""]
        ];
    }
}