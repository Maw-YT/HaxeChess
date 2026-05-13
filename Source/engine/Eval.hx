package engine;

import config.GameConfig;
import config.PieceCatalog;
import config.PieceCatalogMetrics;
import utils.BoardUtils;
import pieces.PieceFactory;
import engine.EvalBackend.IEvalBackend;
import engine.EvalBackend.ClassicalEvalBackend;
import engine.EvalPieceSquareTables;

typedef EvalAccumulator = {
    var materialW:Int;
    var materialB:Int;
    var pstW:Int;
    var pstB:Int;
};

/**
 * Classical eval: material + piece-square tables (8×8 standard) + lightweight structure.
 * Non-standard boards use a simple geometric fallback PST.
 */
class Eval {
    static var backend:IEvalBackend = new ClassicalEvalBackend();

    /** Small bonus for the side to move (centipawns scaled to engine units). */
    public static inline var TEMPO:Int = 1;
    static inline var BISHOP_PAIR:Int = 2;
    static inline var PASSED_PAWN_BASE:Int = 2;
    static inline var DOUBLED_PAWN:Int = -1;
    static inline var ISOLATED_PAWN:Int = -2;
    static inline var ROOK_SEMI_OPEN:Int = 2;
    static inline var ROOK_OPEN_EXTRA:Int = 1;

    public static function setBackend(next:IEvalBackend):Void {
        if (next != null)
            backend = next;
    }

    public static function backendId():String {
        return backend.id();
    }

    public static function build(board:Array<Array<String>>):EvalAccumulator {
        return backend.build(board);
    }

    public static function classicalBuild(board:Array<Array<String>>):EvalAccumulator {
        var acc:EvalAccumulator = {materialW: 0, materialB: 0, pstW: 0, pstB: 0};
        if (board == null || board.length == 0)
            return acc;
        var rows = board.length;
        var cols = rows > 0 && board[0] != null ? board[0].length : 8;
        for (r in 0...rows) {
            var row = board[r];
            if (row == null)
                continue;
            for (c in 0...row.length) {
                var id = row[c];
                if (id == "")
                    continue;
                var p = BoardUtils.parsePieceId(id);
                var v = pieceValue(p.type);
                var pst = pstForPiece(p.type, p.color, r, c, rows, cols);
                if (p.color == "w") {
                    acc.materialW += v;
                    acc.pstW += pst;
                } else {
                    acc.materialB += v;
                    acc.pstB += pst;
                }
            }
        }
        return acc;
    }

    public static function clone(a:EvalAccumulator):EvalAccumulator {
        return backend.clone(a);
    }

    public static function classicalClone(a:EvalAccumulator):EvalAccumulator {
        return {materialW: a.materialW, materialB: a.materialB, pstW: a.pstW, pstB: a.pstB};
    }

    public static function updateNormalMove(acc:EvalAccumulator, movedPieceId:String, fromR:Int, fromC:Int, toR:Int, toC:Int, capturedPieceId:String,
            boardRows:Int, boardCols:Int):Void {
        backend.updateNormalMove(acc, movedPieceId, fromR, fromC, toR, toC, capturedPieceId, boardRows, boardCols);
    }

    public static function classicalUpdateNormalMove(acc:EvalAccumulator, movedPieceId:String, fromR:Int, fromC:Int, toR:Int, toC:Int, capturedPieceId:String,
            boardRows:Int, boardCols:Int):Void {
        if (movedPieceId == "")
            return;
        var mp = BoardUtils.parsePieceId(movedPieceId);
        var pstFrom = pstForPiece(mp.type, mp.color, fromR, fromC, boardRows, boardCols);
        var pstTo = pstForPiece(mp.type, mp.color, toR, toC, boardRows, boardCols);

        if (mp.color == "w")
            acc.pstW += (pstTo - pstFrom);
        else
            acc.pstB += (pstTo - pstFrom);

        if (capturedPieceId != null && capturedPieceId != "") {
            var cp = BoardUtils.parsePieceId(capturedPieceId);
            var cv = pieceValue(cp.type);
            var cpst = pstForPiece(cp.type, cp.color, toR, toC, boardRows, boardCols);
            if (cp.color == "w") {
                acc.materialW -= cv;
                acc.pstW -= cpst;
            } else {
                acc.materialB -= cv;
                acc.pstB -= cpst;
            }
        }
    }

    public static function score(acc:EvalAccumulator, sideToMove:String):Int {
        return backend.score(acc, sideToMove);
    }

    public static function classicalScore(acc:EvalAccumulator, sideToMove:String):Int {
        var s = (acc.materialW + acc.pstW) - (acc.materialB + acc.pstB);
        return sideToMove == "w" ? s : -s;
    }

    /**
     * Material + PST + structure + tapered king (no mobility — needs `LeafEval.evaluate` for that).
     */
    public static function evaluateWithStructure(board:Array<Array<String>>, acc:EvalAccumulator, sideToMove:String):Int {
        var raw = (acc.materialW + acc.pstW) - (acc.materialB + acc.pstB);
        if (board != null && board.length == 8 && board[0] != null && board[0].length == 8 && GameConfig.isStandardChessBoard()) {
            raw += structureNetWhite(board);
            raw += kingTaperNetWhite(board);
            raw += kingMatingTropismNetWhite(board);
        }
        return finalizeScoreFromWhitePerspective(raw, sideToMove);
    }

    /** `raw` is white-centric (positive = white better); applies tempo and side-to-move flip. */
    public static function finalizeScoreFromWhitePerspective(raw:Int, sideToMove:String):Int {
        if (sideToMove == "w") {
            raw += TEMPO;
            return raw;
        }
        raw -= TEMPO;
        return -raw;
    }

    /**
     * Opening weight 0..256 from non-king material (256 = rich middlegame, 0 = bare kings / pawn ending).
     */
    public static function openingPhase256(board:Array<Array<String>>):Int {
        if (board == null || board.length == 0)
            return 0;
        var u = 0;
        for (r in 0...board.length) {
            var row = board[r];
            if (row == null)
                continue;
            for (c in 0...row.length) {
                var id = row[c];
                if (id == "")
                    continue;
                var p = BoardUtils.parsePieceId(id);
                if (p.type == "king")
                    continue;
                u += PieceCatalog.openingPhaseWeight(p.type);
            }
        }
        return u > 256 ? 256 : u;
    }

    /** Piece types that should trigger king-vs-bare-king tropism (driving own king into the box). */
    static function isMatingTropismPieceType(t:String):Bool {
        return t == "queen"
            || t == "rook"
            || t == "amazon"
            || t == "chancellor"
            || t == "archbishop"
            || t == "centaur"
            || t == "royalknight"
            || t == "knight"
            || t == "nightrider"
            || t == "zebra"
            || t == "grasshopper";
    }

    /**
     * Encourage the strong side's king to approach a bare enemy king when mating material exists
     * (Q/R/amazon/chancellor/archbishop, or leapers like centaur / royal knight / knight, etc.).
     * Manhattan distance 0..14 on 8×8.
     */
    public static function kingMatingTropismNetWhite(board:Array<Array<String>>):Int {
        if (board == null || board.length != 8 || board[0] == null || board[0].length != 8 || !GameConfig.isStandardChessBoard())
            return 0;
        var wk = findKingSquare8(board, "w");
        var bk = findKingSquare8(board, "b");
        if (wk == null || bk == null)
            return 0;
        var wExtra = 0;
        var bExtra = 0;
        var wMajor = false;
        var bMajor = false;
        for (r in 0...8) {
            for (c in 0...8) {
                var id = board[r][c];
                if (id == "")
                    continue;
                var p = BoardUtils.parsePieceId(id);
                var royalPc = PieceFactory.createPiece(id);
                if (royalPc != null && royalPc.isRoyal())
                    continue;
                if (p.color == "w") {
                    wExtra++;
                    if (isMatingTropismPieceType(p.type))
                        wMajor = true;
                } else {
                    bExtra++;
                    if (isMatingTropismPieceType(p.type))
                        bMajor = true;
                }
            }
        }
        var d = Std.int(Math.abs(wk.r - bk.r) + Math.abs(wk.c - bk.c));
        var ring = 14 - d;
        if (ring < 0)
            ring = 0;
        var trop = 1;
        var s = 0;
        if (bExtra == 0 && wMajor)
            s += ring * trop;
        if (wExtra == 0 && bMajor)
            s -= ring * trop;
        return s;
    }

    /** Replace MG-only king PST in `acc` with MG/EG blend: correction from white's POV. */
    public static function kingTaperNetWhite(board:Array<Array<String>>):Int {
        if (board == null || board.length != 8 || board[0] == null || board[0].length != 8 || !GameConfig.isStandardChessBoard())
            return 0;
        var wk = findKingSquare8(board, "w");
        var bk = findKingSquare8(board, "b");
        if (wk == null || bk == null)
            return 0;
        var ph = openingPhase256(board);
        var iw = kingTableIndices("w", wk.r, wk.c);
        var ib = kingTableIndices("b", bk.r, bk.c);
        var mgW = EvalPieceSquareTables.KING_MG_W[iw.tr][iw.tc];
        var egW = EvalPieceSquareTables.KING_EG_W[iw.tr][iw.tc];
        var mgB = EvalPieceSquareTables.KING_MG_W[ib.tr][ib.tc];
        var egB = EvalPieceSquareTables.KING_EG_W[ib.tr][ib.tc];
        var blendW = (ph * mgW + (256 - ph) * egW) >> 8;
        var blendB = (ph * mgB + (256 - ph) * egB) >> 8;
        return (blendW - mgW) - (blendB - mgB);
    }

    /**
     * Square of the side's standard king if present, otherwise the first royal piece (e.g. royal knight).
     * Used for king PST / tropism when layouts omit a classical king.
     */
    static function findKingSquare8(board:Array<Array<String>>, color:String):Null<{r:Int, c:Int}> {
        for (r in 0...8) {
            for (c in 0...8) {
                var id = board[r][c];
                if (id == "")
                    continue;
                var p = BoardUtils.parsePieceId(id);
                if (p.color != color)
                    continue;
                if (p.type == "king")
                    return {r: r, c: c};
            }
        }
        for (r in 0...8) {
            for (c in 0...8) {
                var id2 = board[r][c];
                if (id2 == "" || !BoardUtils.isPieceOfColor(id2, color))
                    continue;
                var pc = PieceFactory.createPiece(id2);
                if (pc != null && pc.isRoyal())
                    return {r: r, c: c};
            }
        }
        return null;
    }

    static function kingTableIndices(color:String, row:Int, col:Int):{tr:Int, tc:Int} {
        var tr = color == "w" ? (7 - row) : row;
        var tc = color == "w" ? col : (7 - col);
        if (tr < 0)
            tr = 0;
        if (tr > 7)
            tr = 7;
        if (tc < 0)
            tc = 0;
        if (tc > 7)
            tc = 7;
        return {tr: tr, tc: tc};
    }

    static function pieceValue(t:String):Int {
        return GameConfig.PIECE_VALUES.exists(t) ? GameConfig.PIECE_VALUES.get(t) : 0;
    }

    static function pstForPiece(t:String, color:String, row:Int, col:Int, rows:Int, cols:Int):Int {
        if (rows == 8 && cols == 8 && GameConfig.isStandardChessBoard())
            return pstStandard8(t, color, row, col);
        return pieceSquareFallback(t, color, row, col, rows, cols);
    }

    static function pstStandard8(t:String, color:String, row:Int, col:Int):Int {
        var tr = color == "w" ? (7 - row) : row;
        var tc = color == "w" ? col : (7 - col);
        if (tr < 0)
            tr = 0;
        if (tr > 7)
            tr = 7;
        if (tc < 0)
            tc = 0;
        if (tc > 7)
            tc = 7;
        switch (PieceCatalog.pstKind(t)) {
            case PieceCatalogMetrics.PST_PAWN:
                return EvalPieceSquareTables.PAWN_W[tr][tc];
            case PieceCatalogMetrics.PST_KNIGHT:
                return EvalPieceSquareTables.KNIGHT_W[tr][tc];
            case PieceCatalogMetrics.PST_BISHOP:
                return EvalPieceSquareTables.BISHOP_W[tr][tc];
            case PieceCatalogMetrics.PST_ROOK:
                return EvalPieceSquareTables.ROOK_W[tr][tc];
            case PieceCatalogMetrics.PST_QUEEN:
                return EvalPieceSquareTables.QUEEN_W[tr][tc];
            case PieceCatalogMetrics.PST_AMAZON:
                return EvalPieceSquareTables.QUEEN_W[tr][tc];
            case PieceCatalogMetrics.PST_CHANCELLOR:
                return EvalPieceSquareTables.ROOK_W[tr][tc];
            case PieceCatalogMetrics.PST_ARCHBISHOP, PieceCatalogMetrics.PST_GRASSHOPPER:
                return EvalPieceSquareTables.BISHOP_W[tr][tc];
            case PieceCatalogMetrics.PST_KNIGHT_LIKE:
                return EvalPieceSquareTables.KNIGHT_W[tr][tc];
            case PieceCatalogMetrics.PST_KING_MG:
                return EvalPieceSquareTables.KING_MG_W[tr][tc];
            default:
                return pieceSquareFallback(t, color, row, col, 8, 8);
        }
    }

    static function pieceSquareFallback(t:String, color:String, row:Int, col:Int, rows:Int, cols:Int):Int {
        var centerC = (cols - 1) * 0.5;
        var centerR = (rows - 1) * 0.5;
        var dist = Math.abs(col - centerC) + Math.abs(row - centerR);
        var central = Std.int(10 - dist);
        var advance = 0;
        if (t == "pawn" || t == "royalpawn") {
            advance = color == "w" ? (rows - 1 - row) : row;
        }
        if (PieceCatalog.fallbackKingCentral(t))
            central = -Std.int(dist);
        return central + advance;
    }

    /** White advantage from structure (pawns, rooks, bishops). */
    public static function structureNetWhite(board:Array<Array<String>>):Int {
        return sideStructure(board, "w") - sideStructure(board, "b");
    }

    static function sideStructure(board:Array<Array<String>>, color:String):Int {
        var s = 0;
        s += bishopPairBonus(board, color);
        s += pawnStructureScore(board, color);
        s += rookOpenFiles(board, color);
        return s;
    }

    static function bishopPairBonus(board:Array<Array<String>>, color:String):Int {
        var n = 0;
        for (r in 0...8) {
            var row = board[r];
            if (row == null)
                continue;
            for (c in 0...row.length) {
                var id = row[c];
                if (id == "")
                    continue;
                var p = BoardUtils.parsePieceId(id);
                if (p.color == color && p.type == "bishop")
                    n++;
            }
        }
        return n >= 2 ? BISHOP_PAIR : 0;
    }

    static function countPawnsOnFile(board:Array<Array<String>>, col:Int, color:String):Int {
        var n = 0;
        for (r in 0...8) {
            var id = board[r][col];
            if (id == "")
                continue;
            var p = BoardUtils.parsePieceId(id);
            if (p.type == "pawn" && p.color == color)
                n++;
        }
        return n;
    }

    static function hasPawnOnFiles(board:Array<Array<String>>, colLo:Int, colHi:Int, color:String):Bool {
        for (c in colLo...colHi + 1) {
            if (c < 0 || c > 7)
                continue;
            if (countPawnsOnFile(board, c, color) > 0)
                return true;
        }
        return false;
    }

    static function pawnStructureScore(board:Array<Array<String>>, color:String):Int {
        var s = 0;
        var filesWith = [for (_ in 0...8) 0];
        for (r in 0...8) {
            for (c in 0...8) {
                var id = board[r][c];
                if (id == "")
                    continue;
                var p = BoardUtils.parsePieceId(id);
                if (p.type != "pawn" || p.color != color)
                    continue;
                filesWith[c]++;
            }
        }
        for (c in 0...8) {
            var k = filesWith[c];
            if (k >= 2)
                s += DOUBLED_PAWN * (k - 1);
        }
        for (r in 0...8) {
            for (c in 0...8) {
                var id = board[r][c];
                if (id == "")
                    continue;
                var p = BoardUtils.parsePieceId(id);
                if (p.type != "pawn" || p.color != color)
                    continue;
                if (!hasPawnOnFiles(board, c - 1, c + 1, color))
                    s += ISOLATED_PAWN;
                if (isPassedPawn(board, r, c, color))
                    s += passedPawnBonus(r, color);
            }
        }
        return s;
    }

    static function isPassedPawn(board:Array<Array<String>>, row:Int, col:Int, color:String):Bool {
        var opp = color == "w" ? "b" : "w";
        if (color == "w") {
            for (pr in 0...row) {
                for (dc in -1...2) {
                    var pc = col + dc;
                    if (pc < 0 || pc > 7)
                        continue;
                    var id = board[pr][pc];
                    if (id == "")
                        continue;
                    var p = BoardUtils.parsePieceId(id);
                    if (p.type == "pawn" && p.color == opp)
                        return false;
                }
            }
        } else {
            for (pr in row + 1...8) {
                for (dc in -1...2) {
                    var pc = col + dc;
                    if (pc < 0 || pc > 7)
                        continue;
                    var id = board[pr][pc];
                    if (id == "")
                        continue;
                    var p = BoardUtils.parsePieceId(id);
                    if (p.type == "pawn" && p.color == opp)
                        return false;
                }
            }
        }
        return true;
    }

    static function passedPawnBonus(row:Int, color:String):Int {
        if (color == "w") {
            var adv = 7 - row;
            return PASSED_PAWN_BASE + Std.int(Math.max(0, adv - 2));
        }
        var advB = row;
        return PASSED_PAWN_BASE + Std.int(Math.max(0, advB - 2));
    }

    static function rookOpenFiles(board:Array<Array<String>>, color:String):Int {
        var s = 0;
        var opp = color == "w" ? "b" : "w";
        for (r in 0...8) {
            for (c in 0...8) {
                var id = board[r][c];
                if (id == "")
                    continue;
                var p = BoardUtils.parsePieceId(id);
                if (p.type != "rook" || p.color != color)
                    continue;
                if (countPawnsOnFile(board, c, color) != 0)
                    continue;
                s += ROOK_SEMI_OPEN;
                if (countPawnsOnFile(board, c, opp) == 0)
                    s += ROOK_OPEN_EXTRA;
            }
        }
        return s;
    }
}
