package config;

import StringTools;

typedef LayoutChoice = {
    var id:String;
    var label:String;
};

/**
 * Board layout presets and lookup by saved id.
 * Only standard chess, Chess960, and Double Chess are supported.
 */
class BoardLayout {
    public static inline var DEFAULT_LAYOUT_ID:String = "classic";

    /**
     * Double Chess (16×12): two standard armies side by side (files a–h and i–p),
     * with a larger center gap between pawn lines.
     */
    public static function getDoubleChess16x12Layout():Array<Array<String>> {
        var classic = getClassicLayout();
        var rows = new Array<Array<String>>();
        for (r in 0...12) {
            var left:Array<String>;
            if (r == 0)
                left = classic[0].copy();
            else if (r == 1)
                left = classic[1].copy();
            else if (r == 10)
                left = classic[6].copy();
            else if (r == 11)
                left = classic[7].copy();
            else
                left = [for (c in 0...8) ""];
            rows.push(left.concat(left.copy()));
        }
        return rows;
    }

    /**
     * Pure standard chess (kings)
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
     * Chess960 / Fischer Random:
     * - bishops on opposite colors
     * - king placed between the two rooks
     * - all other pieces randomized in remaining back-rank squares
     */
    public static function getChess960Layout():Array<Array<String>> {
        var backRank = [for (i in 0...8) ""];

        // Bishops must be on opposite colors.
        var darkSquares = [0, 2, 4, 6];
        var lightSquares = [1, 3, 5, 7];
        var b1 = darkSquares[Std.random(darkSquares.length)];
        var b2 = lightSquares[Std.random(lightSquares.length)];
        backRank[b1] = "bishop";
        backRank[b2] = "bishop";

        // Queen on one remaining square.
        var remaining = new Array<Int>();
        for (i in 0...8)
            if (backRank[i] == "")
                remaining.push(i);
        var q = remaining.splice(Std.random(remaining.length), 1)[0];
        backRank[q] = "queen";

        // Two knights on two of the remaining squares.
        var n1 = remaining.splice(Std.random(remaining.length), 1)[0];
        var n2 = remaining.splice(Std.random(remaining.length), 1)[0];
        backRank[n1] = "knight";
        backRank[n2] = "knight";

        // Remaining three squares become rook, king, rook in file order (king between rooks).
        remaining.sort(function(a:Int, b:Int):Int return a - b);
        backRank[remaining[0]] = "rook";
        backRank[remaining[1]] = "king";
        backRank[remaining[2]] = "rook";

        var blackBack = [for (i in 0...8) backRank[i] + "-b"];
        var whiteBack = [for (i in 0...8) backRank[i] + "-w"];
        return [
            blackBack,
            ["pawn-b", "pawn-b", "pawn-b", "pawn-b", "pawn-b", "pawn-b", "pawn-b", "pawn-b"],
            ["", "", "", "", "", "", "", ""],
            ["", "", "", "", "", "", "", ""],
            ["", "", "", "", "", "", "", ""],
            ["", "", "", "", "", "", "", ""],
            ["pawn-w", "pawn-w", "pawn-w", "pawn-w", "pawn-w", "pawn-w", "pawn-w", "pawn-w"],
            whiteBack
        ];
    }

    static function copyRows(src:Array<Array<String>>):Array<Array<String>> {
        return [for (r in 0...src.length) [for (c in 0...src[r].length) src[r][c]]];
    }

    static function presetChoices():Array<LayoutChoice> {
        return [
            {id: "classic", label: "Standard chess"},
            {id: "chess960", label: "Chess960 (Fischer Random)"},
            {id: "double_chess_16x12", label: "Double Chess (16×12, two armies)"}
        ];
    }

    /** Built-in presets plus user layouts from {@link CustomLayoutsStore}. */
    public static function layoutChoices():Array<LayoutChoice> {
        var out = presetChoices();
        for (e in CustomLayoutsStore.instance.getAll())
            out.push({id: e.id, label: "★ " + e.name});
        return out;
    }

    /** True if id is a preset or a saved custom layout. */
    public static function isKnownLayoutId(id:String):Bool {
        if (id == null || id == "")
            return false;
        if (id == "classic" || id == "chess960" || id == "double_chess_16x12" || id == "double_chess_16x8")
            return true;
        return StringTools.startsWith(id, "custom_") && CustomLayoutsStore.instance.hasId(id);
    }

    /**
     * Resolve layout by id; unknown ids fall back to standard chess.
     */
    public static function getLayoutById(id:String):Array<Array<String>> {
        if (id == null || id == "")
            return copyRows(getClassicLayout());
        if (StringTools.startsWith(id, "custom_")) {
            var b = CustomLayoutsStore.instance.getBoard(id);
            if (b != null)
                return copyRows(b);
            return copyRows(getClassicLayout());
        }
        switch (id) {
            case "classic":
                return copyRows(getClassicLayout());
            case "chess960":
                return copyRows(getChess960Layout());
            case "double_chess_16x12", "double_chess_16x8":
                return copyRows(getDoubleChess16x12Layout());
            default:
                return copyRows(getClassicLayout());
        }
    }
}
