package utils;

import config.PieceCatalog;
import config.PieceCatalogMetrics;

/**
 * Threefold repetition (position key) and insufficient mating material.
 */
class DrawRules {
    /**
     * FEN-like key for repetition: placement + side to move + castling + en passant
     * (excludes halfmove clock and fullmove number).
     */
    public static function repetitionPositionKey(
        board:Array<Array<String>>,
        sideToMove:String,
        castlingFEN:String,
        enPassantFEN:String
    ):String {
        var placement = BoardToFEN.getPiecePlacement(board);
        var cr = castlingFEN != null && castlingFEN != "" ? castlingFEN : "-";
        var ep = enPassantFEN != null && enPassantFEN != "" ? enPassantFEN : "-";
        return placement + " " + sideToMove + " " + cr + " " + ep;
    }

    /**
     * Automatic draw from piece types: neither side has catalog “heavy” material and the
     * remaining minors match known insufficient combinations (KvK, K+minor v K, etc.).
     */
    public static function isInsufficientMaterial(board:Array<Array<String>>):Bool {
        var heavy = false;
        var wKn = 0;
        var bKn = 0;
        var wB:Array<Bool> = [];
        var bB:Array<Bool> = [];

        for (r in 0...board.length) {
            var row = board[r];
            for (c in 0...row.length) {
                var id = row[c];
                if (id == null || id == "")
                    continue;
                var p = BoardUtils.parsePieceId(id);
                switch (PieceCatalog.drawClass(p.type)) {
                    case PieceCatalogMetrics.DRAW_HEAVY:
                        heavy = true;
                    case PieceCatalogMetrics.DRAW_ROYAL_KING:
                    // ignore (royal king)
                    case PieceCatalogMetrics.DRAW_KNIGHT_MINOR:
                        if (p.color == "w")
                            wKn++;
                        else
                            bKn++;
                    case PieceCatalogMetrics.DRAW_BISHOP:
                        var light = ((c + r) & 1) == 0;
                        if (p.color == "w")
                            wB.push(light);
                        else
                            bB.push(light);
                    case PieceCatalogMetrics.DRAW_DEFAULT_HEAVY:
                        heavy = true;
                }
            }
        }
        if (heavy)
            return false;

        var wMin = wKn + wB.length;
        var bMin = bKn + bB.length;

        if (wMin == 0 && bMin == 0)
            return true;

        if (wMin == 0)
            return sideInsufficientAttackers(bKn, bB);
        if (bMin == 0)
            return sideInsufficientAttackers(wKn, wB);

        if (wKn == 0 && bKn == 0 && wB.length == 1 && bB.length == 1 && wB[0] == bB[0])
            return true;

        if (wB.length == 0 && bB.length == 0 && wKn == 1 && bKn == 1)
            return true;

        return false;
    }

    static function sideInsufficientAttackers(knights:Int, bishops:Array<Bool>):Bool {
        if (knights >= 2)
            return false;
        if (knights == 1 && bishops.length >= 1)
            return false;
        if (knights == 1 && bishops.length == 0)
            return true;
        if (knights == 0 && bishops.length == 0)
            return true;
        if (knights == 0 && bishops.length == 1)
            return true;
        var c0 = bishops[0];
        for (i in 1...bishops.length) {
            if (bishops[i] != c0)
                return false;
        }
        return true;
    }
}
