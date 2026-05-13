package engine;

import config.BoardLayout;

class EvalSuite {
    public static function runDeterminismSuite():{passed:Bool, details:Array<String>} {
        var details:Array<String> = [];
        var board = BoardLayout.getClassicLayout();
        var pos = new Position(board, "w");
        var s0 = LeafEval.evaluate(pos);
        var s1 = LeafEval.evaluate(pos);
        var ok = (s0 == s1);
        details.push("repeat-score: " + s0 + " vs " + s1 + (ok ? " [OK]" : " [FAIL]"));

        var moves = pos.generateLegalMoves();
        var checked = 0;
        for (m in moves) {
            if (checked >= 8)
                break;
            var pre = LeafEval.evaluate(pos);
            pos.makeMove(m);
            pos.unmakeMove();
            var post = LeafEval.evaluate(pos);
            var same = pre == post;
            ok = ok && same;
            details.push("make/unmake " + Search.moveToUciPublic(m) + ": " + pre + " -> " + post + (same ? " [OK]" : " [FAIL]"));
            checked++;
        }
        return {passed: ok, details: details};
    }
}
