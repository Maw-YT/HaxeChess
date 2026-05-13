package engine;

import config.BoardLayout;
import openfl.Lib;

class EngineDiagnostics {
    public static function benchmark(depth:Int, ms:Int):{nps:Int, nodes:Int, elapsed:Int, best:String} {
        var pos = new Position(BoardLayout.getClassicLayout(), "w");
        var res = Search.findBestMoveDetailed(pos, Std.int(Math.max(1, depth)), ms, 0, 1);
        return {
            nps: res.nps,
            nodes: res.nodes,
            elapsed: res.elapsedMs,
            best: res.bestMove != null ? Search.moveToUciPublic(res.bestMove) : ""
        };
    }

    public static function tacticalSmoke():{passed:Bool, details:Array<String>} {
        var details:Array<String> = [];
        var pos = new Position(BoardLayout.getClassicLayout(), "w");
        var res = Search.findBestMoveDetailed(pos, 3, 500, 0, 1);
        var ok = res.bestMove != null;
        details.push("startpos depth3 bestmove present: " + (ok ? "[OK]" : "[FAIL]"));
        return {passed: ok, details: details};
    }

    public static function ttConsistency():{passed:Bool, details:Array<String>} {
        var details:Array<String> = [];
        var p1 = new Position(BoardLayout.getClassicLayout(), "w");
        var p2 = new Position(BoardLayout.getClassicLayout(), "w");
        var r1 = Search.findBestMoveDetailed(p1, 3, 350, 0, 1);
        var r2 = Search.findBestMoveDetailed(p2, 3, 350, 0, 1);
        var b1 = r1.bestMove != null ? Search.moveToUciPublic(r1.bestMove) : "";
        var b2 = r2.bestMove != null ? Search.moveToUciPublic(r2.bestMove) : "";
        var ok = b1 == b2;
        details.push("repeat-search bestmove equal: " + b1 + " / " + b2 + (ok ? " [OK]" : " [FAIL]"));
        return {passed: ok, details: details};
    }

    public static function stabilitySmoke(rounds:Int):{passed:Bool, details:Array<String>} {
        var details:Array<String> = [];
        var pos = new Position(BoardLayout.getClassicLayout(), "w");
        var ok = true;
        for (i in 0...Std.int(Math.max(1, rounds))) {
            var res = Search.findBestMoveDetailed(pos, 2, 180, 0, 1);
            if (res.bestMove == null) {
                ok = false;
                details.push("round " + i + ": no move [FAIL]");
                break;
            }
            pos.makeMove(res.bestMove);
            if (pos.generateLegalMoves().length == 0)
                break;
        }
        if (ok)
            details.push("stability rounds completed [OK]");
        return {passed: ok, details: details};
    }
}
