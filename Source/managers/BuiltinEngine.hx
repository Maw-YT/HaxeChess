package managers;

import engine.Position;
import engine.Search;
import engine.Eval;
import engine.EvalBackend.ClassicalEvalBackend;
import engine.EvalBackend.NnueEvalBackend;
import engine.Tablebase;
import config.SettingsConfig;
import interfaces.IGameController;

class BuiltinEngine {
    public static var lastSearchInfo:Null<engine.SearchResult> = null;
    static var nnueBackend = new NnueEvalBackend();

    static function applyEvalBackendFromSettings():Void {
        Tablebase.configure(SettingsConfig.builtinTablebasePath);
        var choice = SettingsConfig.builtinEvalBackend != null ? SettingsConfig.builtinEvalBackend : "classical";
        if (choice == "nnue_stub") {
            nnueBackend.loadNet(SettingsConfig.builtinNetPath);
            Eval.setBackend(nnueBackend);
        } else {
            Eval.setBackend(new ClassicalEvalBackend());
        }
    }

    public static function runStage1Checks():{passed:Bool, details:Array<String>} {
        return engine.PerftSuite.runStandardStartSuite();
    }

    public static function runEvalChecks():{passed:Bool, details:Array<String>} {
        applyEvalBackendFromSettings();
        return engine.EvalSuite.runDeterminismSuite();
    }

    public static function runDiagnostics():{passed:Bool, details:Array<String>} {
        applyEvalBackendFromSettings();
        var details:Array<String> = [];
        var ok = true;
        var b = engine.EngineDiagnostics.benchmark(4, 1200);
        details.push("benchmark: nodes=" + b.nodes + " nps=" + b.nps + " best=" + b.best + " ms=" + b.elapsed);
        var t = engine.EngineDiagnostics.tacticalSmoke();
        ok = ok && t.passed;
        details = details.concat(t.details);
        var tt = engine.EngineDiagnostics.ttConsistency();
        ok = ok && tt.passed;
        details = details.concat(tt.details);
        var s = engine.EngineDiagnostics.stabilitySmoke(20);
        ok = ok && s.passed;
        details = details.concat(s.details);
        return {passed: ok, details: details};
    }

    public static function chooseMove(controller:IGameController):String {
        return chooseMoveFromSnapshot(controller.getBoardData(), controller.getCurrentTurn(), SettingsConfig.engineDepth);
    }

    static function countOccupiedOnBoard(board:Array<Array<String>>):Int {
        if (board == null)
            return 0;
        var n = 0;
        for (r in 0...board.length) {
            var row = board[r];
            if (row == null)
                continue;
            for (c in 0...row.length) {
                if (row[c] != null && row[c] != "")
                    n++;
            }
        }
        return n;
    }

    public static function chooseMoveFromSnapshot(board:Array<Array<String>>, sideToMove:String, depthSetting:Int, ?timeBudgetMs:Int = -1):String {
        applyEvalBackendFromSettings();
        var pos = new Position(board, sideToMove);
        var depth = Std.int(Math.max(1, depthSetting));
        var thinkMs = timeBudgetMs != null && timeBudgetMs > 0
            ? timeBudgetMs
            : (SettingsConfig.engineTimeMs > 0 ? SettingsConfig.engineTimeMs : 1200);
        var boardArea = board.length > 0 ? board.length * board[0].length : 64;
        var nodeBudget = Std.int(Math.max(120000, 180000 + boardArea * 900));
        var sparse = countOccupiedOnBoard(board) <= 12;
        if (sparse) {
            depth = Std.int(Math.max(depth, 22));
            thinkMs = Std.int(Math.max(thinkMs, 5500));
            nodeBudget = Std.int(Math.max(nodeBudget, 2500000));
        }
        var parsedThreads:Null<Int> = Std.parseInt(SettingsConfig.engineThreads);
        var threads = (SettingsConfig.engineThreads != null && SettingsConfig.engineThreads != "" && parsedThreads != null)
            ? Std.int(Math.max(1, parsedThreads))
            : 1;
        var res = Search.findBestMoveDetailed(pos, depth, thinkMs, nodeBudget, threads);
        lastSearchInfo = res;
        var best = res.bestMove;
        if (best == null)
            return "";
        return utils.ChessNotation.toUCI(best.fromCol, best.fromRow, best.toCol, best.toRow, best.promotion);
    }

    public static function requestStop():Void {
        Search.requestStop();
    }
}
