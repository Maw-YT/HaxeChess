package engine;

import config.GameConfig;
import managers.ValidationManager;
import utils.BoardUtils;
import engine.Position.EngineMove;
import engine.TranspositionTable;
import openfl.Lib;
#if sys
import sys.thread.Thread;
import sys.thread.Deque;
#end

typedef SearchResult = {
    var bestMove:Null<EngineMove>;
    var bestScore:Int;
    var depthReached:Int;
    var nodes:Int;
    var elapsedMs:Int;
    var nps:Int;
    var stopReason:String;
};

class Search {
    static inline var INF:Int = 100000000;
    static inline var MATE:Int = 1000000;
    static inline var MAX_PLY:Int = 128;
    static var tt:TranspositionTable;
    static var historyHeuristic:Map<String, Int>;
    static var killerMoves:Array<Array<String>>;
    static var nodeCount:Int = 0;
    static var nodeLimit:Int = 0;
    static var stopAtMs:Int = 0;
    static var timedOut:Bool = false;
    static var externalStopRequested:Bool = false;
    /** When non-null, positions on the stack from root — revisiting = draw (avoids shuffle loops). Disabled if threads>1. */
    static var repPathStack:Array<String> = null;
    static inline var FUTILITY_MARGIN:Int = 120;
    static inline var DELTA_MARGIN:Int = 180;
    /** Q-search depth cap (check extensions can go deep). */
    static inline var MAX_QUIESCENCE_PLY:Int = 32;
    /** Include non-capture checks in q-search when opening phase is at or below this (endgames). */
    static inline var QUIET_CHECK_PHASE_MAX:Int = 72;

    public static function findBestMove(pos:Position, maxDepth:Int, ?timeLimitMs:Int = 0, ?maxNodes:Int = 0, ?threads:Int = 1):Null<EngineMove> {
        return findBestMoveDetailed(pos, maxDepth, timeLimitMs, maxNodes, threads).bestMove;
    }

    public static function findBestMoveDetailed(pos:Position, maxDepth:Int, ?timeLimitMs:Int = 0, ?maxNodes:Int = 0, ?threads:Int = 1):SearchResult {
        if (tt == null)
            tt = new TranspositionTable();
        historyHeuristic = new Map();
        killerMoves = [];
        for (i in 0...MAX_PLY)
            killerMoves.push([]);
        nodeCount = 0;
        nodeLimit = maxNodes != null ? maxNodes : 0;
        timedOut = false;
        var started = Lib.getTimer();
        stopAtMs = (timeLimitMs != null && timeLimitMs > 0) ? (started + timeLimitMs) : 0;

        var depth = Std.int(Math.max(1, maxDepth));
        var rootMoves = pos.generateLegalMoves();
        if (rootMoves.length == 0)
            return {
                bestMove: null,
                bestScore: -INF,
                depthReached: 0,
                nodes: nodeCount,
                elapsedMs: Lib.getTimer() - started,
                nps: 0,
                stopReason: "no_legal_moves"
            };

        var best = rootMoves[0];
        var bestUci = moveToUci(best);
        var bestScoreOverall = -INF;
        var reached = 0;
        for (d in 1...depth + 1) {
            tt.nextGeneration();
            var bestScore = -INF;
            var alpha = -INF;
            var beta = INF;

            if (d > 1 && bestScoreOverall > -INF / 2) {
                var window = 60;
                alpha = bestScoreOverall - window;
                beta = bestScoreOverall + window;
            }
            var aspAlpha = alpha;
            var aspBeta = beta;

            var ordered = orderMoves(pos, rootMoves, 0, bestUci);
            repPathStack = threads > 1 ? null : [];
            var root = evaluateRootMoves(pos, ordered, d, alpha, beta, threads);
            bestScore = root.bestScore;
            best = root.bestMove != null ? root.bestMove : best;
            bestUci = moveToUci(best);
            alpha = root.alpha;
            if (shouldStop())
                break;
            reached = d;
            bestScoreOverall = bestScore;

            // Aspiration fail high/low re-search with full window.
            if (bestScore <= aspAlpha || bestScore >= aspBeta) {
                var bestScoreWide = -INF;
                alpha = -INF;
                beta = INF;
                ordered = orderMoves(pos, rootMoves, 0, bestUci);
                repPathStack = threads > 1 ? null : [];
                var rootWide = evaluateRootMoves(pos, ordered, d, alpha, beta, threads);
                bestScoreWide = rootWide.bestScore;
                if (rootWide.bestMove != null) {
                    best = rootWide.bestMove;
                    bestUci = moveToUci(best);
                }
                if (bestScoreWide > -INF / 2)
                    bestScoreOverall = bestScoreWide;
            }
        }
        var elapsed = Lib.getTimer() - started;
        var nps = elapsed > 0 ? Std.int((nodeCount * 1000.0) / elapsed) : 0;
        var stopReason = timedOut ? ((nodeLimit > 0 && nodeCount >= nodeLimit) ? "node_limit" : "time_limit") : "completed";
        return {
            bestMove: best,
            bestScore: bestScoreOverall,
            depthReached: reached,
            nodes: nodeCount,
            elapsedMs: elapsed,
            nps: nps,
            stopReason: stopReason
        };
    }

    /**
     * If repPathStack is active: when child position key is already on the path, return drawScore.
     * Otherwise push child key, run f, pop on success or exception.
     */
    static function searchWithRepPathChild(pos:Position, drawScore:Int, f:Void->Int):Int {
        if (repPathStack == null)
            return f();
        var k = pos.repetitionPathKey();
        if (repPathStack.indexOf(k) >= 0)
            return drawScore;
        repPathStack.push(k);
        try {
            var out = f();
            repPathStack.pop();
            return out;
        } catch (e:Dynamic) {
            repPathStack.pop();
            throw e;
        }
    }

    static inline function shouldStop():Bool {
        if (timedOut)
            return true;
        if (externalStopRequested) {
            timedOut = true;
            return true;
        }
        if (nodeLimit > 0 && nodeCount >= nodeLimit) {
            timedOut = true;
            return true;
        }
        if (stopAtMs > 0 && Lib.getTimer() >= stopAtMs) {
            timedOut = true;
            return true;
        }
        return false;
    }

    public static function requestStop():Void {
        externalStopRequested = true;
    }

    public static function clearStop():Void {
        externalStopRequested = false;
    }

    static function alphaBeta(pos:Position, depth:Int, alpha:Int, beta:Int, ply:Int, isPv:Bool):Int {
        if (tt == null)
            tt = new TranspositionTable();
        if (historyHeuristic == null)
            historyHeuristic = new Map();
        if (killerMoves == null) {
            killerMoves = [];
            for (i in 0...MAX_PLY)
                killerMoves.push([]);
        }
        nodeCount++;
        if (shouldStop())
            return evaluate(pos);
        var tb = Tablebase.probe(pos);
        if (tb != null && tb.exact)
            return tb.score;
        if (depth <= 0)
            return quiescence(pos, alpha, beta, ply);

        var inCheckNow = ValidationManager.isCheck(pos.sideToMove, pos.board);

        // Conservative null-move pruning (disabled in check, shallow nodes, and lean endgames
        // where zugzwang / mate walks are common).
        if (depth >= 3 && !inCheckNow && Eval.openingPhase256(pos.board) >= 88) {
            var reduction = 2;
            pos.makeNullMove();
            var nullScore = -alphaBeta(pos, depth - 1 - reduction, -beta, -beta + 1, ply + 1, false);
            pos.unmakeMove();
            if (nullScore >= beta)
                return nullScore;
        }

        var key = pos.toKey();
        var alphaOrig = alpha;
        var ttHit = tt.probe(key);
        var ttMove = "";
        if (ttHit != null) {
            ttMove = ttHit.bestMove;
            if (ttHit.depth >= depth) {
                switch (ttHit.bound) {
                    case TranspositionTable.BOUND_EXACT:
                        return scoreFromTT(ttHit.score, ply);
                    case TranspositionTable.BOUND_LOWER:
                        var low = scoreFromTT(ttHit.score, ply);
                        if (low > alpha)
                            alpha = low;
                    case TranspositionTable.BOUND_UPPER:
                        var up = scoreFromTT(ttHit.score, ply);
                        if (up < beta)
                            beta = up;
                }
                if (alpha >= beta)
                    return scoreFromTT(ttHit.score, ply);
            }
        }

        var moves = pos.generateLegalMoves();
        if (moves.length == 0) {
            var inCheck = ValidationManager.isCheck(pos.sideToMove, pos.board);
            return inCheck ? (-MATE + ply) : 0;
        }

        var a = alpha;
        var ordered = orderMoves(pos, moves, ply, ttMove);
        var bestLocalUci = "";
        var moveIdx = 0;
        var staticEval = evaluate(pos);
        for (m in ordered) {
            var u = moveToUci(m);
            var isQuiet = m.capturedPiece == "" && !m.isEnPassant;

            // Shallow futility pruning for late quiets when not in check (skip in lean endgames:
            // king walks and queen checks need depth to show value).
            if (!inCheckNow && depth <= 2 && isQuiet && moveIdx >= 2 && Eval.openingPhase256(pos.board) > 96) {
                if (staticEval + FUTILITY_MARGIN <= a) {
                    moveIdx++;
                    continue;
                }
            }

            pos.makeMove(m);
            var checkExt = ValidationManager.isCheck(pos.sideToMove, pos.board) ? 1 : 0;
            var sparseBoard = countOccupiedSquares(pos.board) <= 12;
            var doLmr = depth >= 3 && moveIdx >= 3 && isQuiet && !inCheckNow && !isPv && !sparseBoard;
            var score = searchWithRepPathChild(pos, 0, function():Int {
                if (doLmr) {
                    var reducedDepth = depth - 2 + checkExt;
                    if (reducedDepth < 1)
                        reducedDepth = 1;
                    var s = -alphaBeta(pos, reducedDepth, -a - 1, -a, ply + 1, false);
                    if (s > a)
                        s = -alphaBeta(pos, depth - 1 + checkExt, -beta, -a, ply + 1, true);
                    return s;
                }
                return -alphaBeta(pos, depth - 1 + checkExt, -beta, -a, ply + 1, isPv && moveIdx == 0);
            });

            pos.unmakeMove();
            if (score >= beta) {
                if (m.capturedPiece == "" && !m.isEnPassant)
                    noteCutoffQuiet(u, depth, ply);
                tt.store(key, {
                    key: key,
                    depth: depth,
                    score: scoreToTT(score, ply),
                    bound: TranspositionTable.BOUND_LOWER,
                    bestMove: u,
                    generation: 0
                });
                return score;
            }
            if (score > a)
                a = score;
            if (score > alphaOrig)
                bestLocalUci = u;
            moveIdx++;
        }

        var bound = TranspositionTable.BOUND_EXACT;
        if (a <= alphaOrig)
            bound = TranspositionTable.BOUND_UPPER;
        else if (a >= beta)
            bound = TranspositionTable.BOUND_LOWER;
        tt.store(key, {
            key: key,
            depth: depth,
            score: scoreToTT(a, ply),
            bound: bound,
            bestMove: bestLocalUci,
            generation: 0
        });

        return a;
    }

    static function noteCutoffQuiet(uci:String, depth:Int, ply:Int):Void {
        if (uci == null || uci == "")
            return;
        if (historyHeuristic == null)
            historyHeuristic = new Map();
        if (killerMoves == null) {
            killerMoves = [];
            for (i in 0...MAX_PLY)
                killerMoves.push([]);
        }
        if (ply < 0 || ply >= killerMoves.length)
            return;
        var old = historyHeuristic.exists(uci) ? historyHeuristic.get(uci) : 0;
        historyHeuristic.set(uci, old + depth * depth);
        var arr = killerMoves[ply];
        if (arr == null) {
            arr = [];
            killerMoves[ply] = arr;
        }
        if (arr.indexOf(uci) >= 0)
            return;
        arr.unshift(uci);
        while (arr.length > 2)
            arr.pop();
    }

    static function moveToUci(m:EngineMove):String {
        return utils.ChessNotation.toUCI(m.fromCol, m.fromRow, m.toCol, m.toRow, m.promotion);
    }

    public static function moveToUciPublic(m:EngineMove):String {
        return moveToUci(m);
    }

    static function quiescence(pos:Position, alpha:Int, beta:Int, ply:Int):Int {
        nodeCount++;
        if (shouldStop())
            return evaluate(pos);
        if (ply >= MAX_QUIESCENCE_PLY)
            return evaluate(pos);

        var board = pos.board;
        var inCheck = ValidationManager.isCheck(pos.sideToMove, board);

        // In check: must consider all evasions (many are non-captures).
        if (inCheck) {
            var evasions = pos.generateLegalMoves();
            if (evasions.length == 0)
                return -MATE + ply;
            var aCh = alpha;
            var ordCh = orderMoves(pos, evasions, ply, "");
            for (m in ordCh) {
                pos.makeMove(m);
                var scoreCh = searchWithRepPathChild(pos, 0, function():Int {
                    return -quiescence(pos, -beta, -aCh, ply + 1);
                });
                pos.unmakeMove();
                if (scoreCh >= beta)
                    return scoreCh;
                if (scoreCh > aCh)
                    aCh = scoreCh;
            }
            return aCh;
        }

        var stand = evaluate(pos);
        if (stand >= beta)
            return stand;
        var a = alpha;
        if (stand > a)
            a = stand;

        var sparseQ = countOccupiedSquares(board) <= 10;
        var tactical = collectQuiescenceMoves(pos);
        var ordered = orderMoves(pos, tactical, ply, "");
        for (m in ordered) {
            var gain = staticExchangeScore(pos, m);
            var isQuietCheck = m.capturedPiece == "" && !m.isEnPassant && moveGivesCheck(pos, m);
            // Delta pruning for all tactics. Losing queen "checks" were slipping through when
            // checks were exempt; only ease margin for non-queen checks in very lean endgames.
            var delta = DELTA_MARGIN;
            if (isQuietCheck) {
                var mover = moverTypeAt(pos, m);
                if (mover == "queen" || mover == "amazon")
                    delta = DELTA_MARGIN;
                else if (Eval.openingPhase256(pos.board) < 40)
                    delta = DELTA_MARGIN + 120;
            }
            if (!sparseQ && stand + gain + delta <= a)
                continue;
            pos.makeMove(m);
            var score = searchWithRepPathChild(pos, 0, function():Int {
                return -quiescence(pos, -beta, -a, ply + 1);
            });
            pos.unmakeMove();
            if (score >= beta)
                return score;
            if (score > a)
                a = score;
        }
        return a;
    }

    static function collectQuiescenceMoves(pos:Position):Array<EngineMove> {
        var out:Array<EngineMove> = [];
        var caps = pos.generateLegalCaptures();
        for (m in caps)
            out.push(m);
        if (pos.board == null || pos.board.length == 0)
            return out;
        if (!GameConfig.isStandardChessBoard())
            return out;
        if (Eval.openingPhase256(pos.board) > QUIET_CHECK_PHASE_MAX)
            return out;
        var seen = new Map<String, Bool>();
        for (m in caps)
            seen.set(moveToUci(m), true);
        for (m in pos.generateLegalMoves()) {
            if (m.capturedPiece != "" || m.isEnPassant)
                continue;
            var fromId = pos.board[m.fromRow][m.fromCol];
            if (fromId != null && fromId != "") {
                var mt = BoardUtils.parsePieceId(fromId).type;
                if (mt == "queen" || mt == "amazon")
                    continue;
            }
            var u = moveToUci(m);
            if (seen.exists(u))
                continue;
            if (!moveGivesCheck(pos, m))
                continue;
            seen.set(u, true);
            out.push(m);
        }
        // Ultra-sparse: include quiet non-checks so q-search sees mate walks (e.g. dual centaurs).
        if (countOccupiedSquares(pos.board) <= 6) {
            var nQuietExtra = 0;
            for (m2 in pos.generateLegalMoves()) {
                if (m2.capturedPiece != "" || m2.isEnPassant)
                    continue;
                var u2 = moveToUci(m2);
                if (seen.exists(u2))
                    continue;
                if (nQuietExtra >= 28)
                    break;
                seen.set(u2, true);
                out.push(m2);
                nQuietExtra++;
            }
        }
        return out;
    }

    static function moveGivesCheck(pos:Position, m:EngineMove):Bool {
        pos.makeMove(m);
        var chk = ValidationManager.isCheck(pos.sideToMove, pos.board);
        pos.unmakeMove();
        return chk;
    }

    static function moverTypeAt(pos:Position, m:EngineMove):String {
        var id = pos.board[m.fromRow][m.fromCol];
        if (id == null || id == "")
            return "";
        return BoardUtils.parsePieceId(id).type;
    }

    static function evaluate(pos:Position):Int {
        return LeafEval.evaluate(pos);
    }

    static function orderMoves(pos:Position, moves:Array<EngineMove>, ply:Int, ttMove:String):Array<EngineMove> {
        if (moves == null)
            return [];
        var out = moves.copy();
        out.sort(function(a:EngineMove, b:EngineMove):Int {
            return moveScore(pos, b, ply, ttMove) - moveScore(pos, a, ply, ttMove);
        });
        return out;
    }

    static function moveScore(pos:Position, m:EngineMove, ply:Int, ttMove:String):Int {
        if (m == null)
            return -INF;
        if (killerMoves == null) {
            killerMoves = [];
            for (i in 0...MAX_PLY)
                killerMoves.push([]);
        }
        if (historyHeuristic == null)
            historyHeuristic = new Map();
        var u = moveToUci(m);
        if (ttMove != "" && u == ttMove)
            return 10000000;
        var s = 0;
        if (m.capturedPiece != "") {
            var p = BoardUtils.parsePieceId(m.capturedPiece);
            s += GameConfig.PIECE_VALUES.exists(p.type) ? GameConfig.PIECE_VALUES.get(p.type) * 100 : 0;
        }
        if (m.isEnPassant)
            s += 90;
        if (m.isCastling)
            s += 40;
        if (m.capturedPiece == "" && !m.isEnPassant) {
            if (ply >= 0 && ply < killerMoves.length) {
                var arr = killerMoves[ply];
                if (arr != null) {
                    if (arr.length > 0 && arr[0] == u)
                        s += 8000;
                    else if (arr.length > 1 && arr[1] == u)
                        s += 7000;
                }
            }
            if (historyHeuristic.exists(u))
                s += historyHeuristic.get(u);
        }
        return s;
    }

    static function captureGain(m:EngineMove):Int {
        if (m.capturedPiece == "")
            return m.isEnPassant ? GameConfig.PIECE_VALUES.get("pawn") : 0;
        var p = BoardUtils.parsePieceId(m.capturedPiece);
        return GameConfig.PIECE_VALUES.exists(p.type) ? GameConfig.PIECE_VALUES.get(p.type) : 0;
    }

    /**
     * One-step exchange hint for captures: victim minus half attacker value (from square before move).
     * Quiet moves return 0 so delta pruning does not treat Nf3+ like a hanging piece.
     */
    static function staticExchangeScore(pos:Position, m:EngineMove):Int {
        if (m.isCastling)
            return 0;
        if (m.capturedPiece == "" && !m.isEnPassant)
            return 0;
        var victim = captureGain(m);
        var attackerVal = 0;
        var id = pos.board[m.fromRow][m.fromCol];
        if (id != null && id != "") {
            var p = BoardUtils.parsePieceId(id);
            attackerVal = GameConfig.PIECE_VALUES.exists(p.type) ? GameConfig.PIECE_VALUES.get(p.type) : 0;
        }
        return victim - (attackerVal >> 1);
    }

    static inline function scoreToTT(score:Int, ply:Int):Int {
        if (score > MATE - 10000)
            return score + ply;
        if (score < -MATE + 10000)
            return score - ply;
        return score;
    }

    static inline function scoreFromTT(score:Int, ply:Int):Int {
        if (score > MATE - 10000)
            return score - ply;
        if (score < -MATE + 10000)
            return score + ply;
        return score;
    }

    static function evaluateRootMoves(pos:Position, ordered:Array<EngineMove>, depth:Int, alpha:Int, beta:Int, threads:Int):{bestMove:Null<EngineMove>, bestScore:Int, alpha:Int} {
        #if sys
        if (threads > 1 && ordered.length > 1 && depth >= 2) {
            var q:Deque<Dynamic> = new Deque();
            var n = Std.int(Math.min(threads, ordered.length));
            for (i in 0...n) {
                var m = ordered[i];
                var side = pos.sideToMove;
                var boardCopy = BoardUtils.copyBoard(pos.board);
                var move = m;
                var boardLocal = boardCopy;
                Thread.create(function() {
                    try {
                        var p2 = new Position(boardLocal, side);
                        p2.makeMove(move);
                        var ext0 = ValidationManager.isCheck(p2.sideToMove, p2.board) ? 1 : 0;
                        var sc = -alphaBeta(p2, depth - 1 + ext0, -beta, -alpha, 1, true);
                        q.add({m: move, s: sc});
                    } catch (e:Dynamic) {
                        q.add({m: move, s: -INF});
                    }
                });
            }
            var bestScore = -INF;
            var bestMove:Null<EngineMove> = null;
            var a = alpha;
            var got = 0;
            while (got < n) {
                if (shouldStop())
                    break;
                var msg = q.pop(true);
                if (msg == null)
                    continue;
                got++;
                var sc = Std.int(msg.s);
                var mv:EngineMove = cast msg.m;
                if (sc > bestScore) {
                    bestScore = sc;
                    bestMove = mv;
                }
                if (sc > a)
                    a = sc;
            }
            for (i in n...ordered.length) {
                if (shouldStop())
                    break;
                var m = ordered[i];
                pos.makeMove(m);
                var extI = ValidationManager.isCheck(pos.sideToMove, pos.board) ? 1 : 0;
                var score = -alphaBeta(pos, depth - 1 + extI, -beta, -a, 1, true);
                pos.unmakeMove();
                if (score > bestScore) {
                    bestScore = score;
                    bestMove = m;
                }
                if (score > a)
                    a = score;
            }
            return {bestMove: bestMove, bestScore: bestScore, alpha: a};
        }
        #end
        var pushedRoot = false;
        if (repPathStack != null) {
            repPathStack.push(pos.repetitionPathKey());
            pushedRoot = true;
        }
        try {
            var bestScore = -INF;
            var bestMove:Null<EngineMove> = null;
            var a = alpha;
            for (m in ordered) {
                if (shouldStop())
                    break;
                pos.makeMove(m);
                var extR = ValidationManager.isCheck(pos.sideToMove, pos.board) ? 1 : 0;
                var score = searchWithRepPathChild(pos, 0, function():Int {
                    return -alphaBeta(pos, depth - 1 + extR, -beta, -a, 1, true);
                });
                pos.unmakeMove();
                if (score > bestScore) {
                    bestScore = score;
                    bestMove = m;
                }
                if (score > a)
                    a = score;
            }
            var out = {bestMove: bestMove, bestScore: bestScore, alpha: a};
            if (pushedRoot)
                repPathStack.pop();
            return out;
        } catch (e:Dynamic) {
            if (pushedRoot)
                repPathStack.pop();
            throw e;
        }
    }

    static function countOccupiedSquares(board:Array<Array<String>>):Int {
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
}
