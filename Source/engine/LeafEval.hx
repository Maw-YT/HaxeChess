package engine;

import config.GameConfig;

/**
 * Full static evaluation at a leaf (structure, tapered king, mobility).
 * Kept separate from `Eval` to avoid a circular import with `Position`.
 */
class LeafEval {
    static inline var MOBILITY_SHIFT:Int = 3;

    public static function evaluate(pos:Position):Int {
        var board = pos.board;
        var acc = pos.acc;
        var raw = (acc.materialW + acc.pstW) - (acc.materialB + acc.pstB);
        if (board != null && board.length == 8 && board[0] != null && board[0].length == 8 && GameConfig.isStandardChessBoard()) {
            raw += Eval.structureNetWhite(board);
            raw += Eval.kingTaperNetWhite(board);
            raw += Eval.kingMatingTropismNetWhite(board);
            raw += mobilityNetWhite(pos);
        }
        return Eval.finalizeScoreFromWhitePerspective(raw, pos.sideToMove);
    }

    static function mobilityNetWhite(pos:Position):Int {
        var wm = pos.countLegalMovesForColor("w");
        var bm = pos.countLegalMovesForColor("b");
        return (wm - bm) >> MOBILITY_SHIFT;
    }
}
