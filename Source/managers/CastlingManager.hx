package managers;

import openfl.geom.Point;
import StringTools;
import utils.BoardUtils;
import pieces.PieceFactory;

typedef CastlingLane = {
    var base:Int;
    var kingHomeCol:Int;
    var queenRookHomeCol:Int;
    var kingRookHomeCol:Int;
    var kingMoved:Bool;
    var queenRookMoved:Bool;
    var kingRookMoved:Bool;
};

class CastlingManager {
    public static inline var KINGSIDE_KING_DEST_COL:Int = 6;
    public static inline var QUEENSIDE_KING_DEST_COL:Int = 2;
    public static inline var KINGSIDE_ROOK_DEST_COL:Int = 5;
    public static inline var QUEENSIDE_ROOK_DEST_COL:Int = 3;

    private var whiteLanes:Array<CastlingLane> = null;
    private var blackLanes:Array<CastlingLane> = null;
    private var pendingFenCastle:String = null;

    public static var instance:CastlingManager;

    public function new() {
        instance = this;
    }

    static inline function segmentBase(col:Int):Int {
        return Std.int(col / 8) * 8;
    }

    static inline function destKingCol(base:Int, side:String):Int {
        return base + (side == "kingside" ? KINGSIDE_KING_DEST_COL : QUEENSIDE_KING_DEST_COL);
    }

    static inline function destRookCol(base:Int, side:String):Int {
        return base + (side == "kingside" ? KINGSIDE_ROOK_DEST_COL : QUEENSIDE_ROOK_DEST_COL);
    }

    public static function sideFromKingDestination(endCol:Int, ?kingStartCol:Int):String {
        var base = kingStartCol != null ? segmentBase(kingStartCol) : 0;
        if (endCol == base + KINGSIDE_KING_DEST_COL)
            return "kingside";
        if (endCol == base + QUEENSIDE_KING_DEST_COL)
            return "queenside";
        if (kingStartCol == null) {
            if (endCol == KINGSIDE_KING_DEST_COL)
                return "kingside";
            if (endCol == QUEENSIDE_KING_DEST_COL)
                return "queenside";
        }
        return null;
    }

    /**
     * True castling only: king on home rank, empty destination, rights/path/checks OK,
     * and destination is the legal castle square for this king (not a normal step onto c/g).
     */
    public function getCastlingSideIfMove(color:String, board:Array<Array<String>>, startX:Int, startY:Int, endX:Int, endY:Int):String {
        if (board == null || color == null || color == "")
            return null;
        if (endY != startY)
            return null;
        if (startY < 0 || startY >= board.length)
            return null;
        if (board[startY] == null || startX < 0 || startX >= board[startY].length)
            return null;
        if (endY < 0 || endY >= board.length)
            return null;
        if (board[endY] == null || endX < 0 || endX >= board[endY].length)
            return null;
        if (board[endY][endX] != "")
            return null;
        var rowIdx = homeRowFor(color, board);
        if (startY != rowIdx)
            return null;
        var lane = getLane(color, "kingside", board, startX);
        if (lane == null)
            return null;
        if (endX == destKingCol(lane.base, "kingside") && canCastle(color, "kingside", board, startX))
            return "kingside";
        if (endX == destKingCol(lane.base, "queenside") && canCastle(color, "queenside", board, startX))
            return "queenside";
        return null;
    }

    function homeRowFor(color:String, board:Array<Array<String>>):Int {
        return color == "w" ? (board.length - 1) : 0;
    }

    function lanesFor(color:String):Array<CastlingLane> {
        return color == "w" ? whiteLanes : blackLanes;
    }

    function setLanesFor(color:String, lanes:Array<CastlingLane>):Void {
        if (color == "w")
            whiteLanes = lanes;
        else
            blackLanes = lanes;
    }

    function discoverLanesIfNeeded(color:String, board:Array<Array<String>>):Void {
        if (board == null || lanesFor(color) != null)
            return;
        var row = homeRowFor(color, board);
        if (row < 0 || row >= board.length)
            return;
        if (board[row] == null)
            return;

        var boardCols = board[row].length;
        var kings:Array<Int> = [];
        for (c in 0...boardCols)
            if (board[row][c] == "king-" + color)
                kings.push(c);
        kings.sort(function(a:Int, b:Int):Int return a - b);

        var lanes:Array<CastlingLane> = [];
        for (kingCol in kings) {
            var base = segmentBase(kingCol);
            var maxCol = Std.int(Math.min(boardCols - 1, base + 7));
            var qRook = -1;
            var kRook = -1;

            for (c in base...maxCol + 1) {
                if (board[row][c] != "rook-" + color)
                    continue;
                if (c < kingCol && c > qRook)
                    qRook = c;
                if (c > kingCol && (kRook < 0 || c < kRook))
                    kRook = c;
            }

            lanes.push({
                base: base,
                kingHomeCol: kingCol,
                queenRookHomeCol: qRook,
                kingRookHomeCol: kRook,
                kingMoved: false,
                queenRookMoved: false,
                kingRookMoved: false
            });
        }

        setLanesFor(color, lanes);
        applyPendingFenIfPossible();
    }

    function discoverAllIfNeeded(board:Array<Array<String>>):Void {
        discoverLanesIfNeeded("w", board);
        discoverLanesIfNeeded("b", board);
    }

    function getLane(color:String, side:String, board:Array<Array<String>>, ?kingStartCol:Int):CastlingLane {
        discoverLanesIfNeeded(color, board);
        var lanes = lanesFor(color);
        if (lanes == null || lanes.length == 0)
            return null;

        if (kingStartCol != null) {
            for (lane in lanes)
                if (lane.kingHomeCol == kingStartCol)
                    return lane;
            return null;
        }

        if (lanes.length == 1)
            return lanes[0];
        return null;
    }

    function isPathClear(row:Array<String>, fromCol:Int, toCol:Int, ?ignoreColA:Int = -1, ?ignoreColB:Int = -1):Bool {
        if (fromCol == toCol)
            return true;
        var step = toCol > fromCol ? 1 : -1;
        var c = fromCol + step;
        while (true) {
            if (c < 0 || c >= row.length)
                return false;
            if (c != ignoreColA && c != ignoreColB && row[c] != "")
                return false;
            if (c == toCol)
                return true;
            c += step;
        }
        return true;
    }

    function kingPathSquares(fromCol:Int, toCol:Int):Array<Int> {
        var out:Array<Int> = [];
        if (fromCol == toCol)
            return out;
        var step = toCol > fromCol ? 1 : -1;
        var c = fromCol + step;
        while (true) {
            out.push(c);
            if (c == toCol)
                break;
            c += step;
        }
        return out;
    }

    function isSquareAttackedByEnemy(defenderColor:String, row:Int, col:Int, board:Array<Array<String>>):Bool {
        if (board == null)
            return false;
        var oldValidating = ValidationManager.isValidating;
        ValidationManager.isValidating = true;
        for (r in 0...board.length) {
            var line = board[r];
            if (line == null)
                continue;
            for (c in 0...line.length) {
                var id = line[c];
                if (id == "" || BoardUtils.isPieceOfColor(id, defenderColor))
                    continue;
                var p = PieceFactory.createPiece(id);
                if (p == null)
                    continue;
                var captures = p.getCaptureMoves(r, c, board);
                for (mv in captures) {
                    if (Std.int(mv.y) == row && Std.int(mv.x) == col) {
                        ValidationManager.isValidating = oldValidating;
                        return true;
                    }
                }
            }
        }
        ValidationManager.isValidating = oldValidating;
        return false;
    }

    function applyPendingFenIfPossible():Void {
        if (pendingFenCastle == null)
            return;
        var fen = pendingFenCastle;
        var w = whiteLanes != null && whiteLanes.length > 0 ? whiteLanes[0] : null;
        var b = blackLanes != null && blackLanes.length > 0 ? blackLanes[0] : null;
        if (w != null) {
            w.kingRookMoved = !StringTools.contains(fen, "K");
            w.queenRookMoved = !StringTools.contains(fen, "Q");
            w.kingMoved = !(StringTools.contains(fen, "K") || StringTools.contains(fen, "Q"));
        }
        if (b != null) {
            b.kingRookMoved = !StringTools.contains(fen, "k");
            b.queenRookMoved = !StringTools.contains(fen, "q");
            b.kingMoved = !(StringTools.contains(fen, "k") || StringTools.contains(fen, "q"));
        }
        pendingFenCastle = null;
    }

    public function getCastlingRookColumns(color:String, side:String, board:Array<Array<String>>, ?kingStartCol:Int):{startCol:Int, endCol:Int} {
        var lane = getLane(color, side, board, kingStartCol);
        var base = kingStartCol != null ? segmentBase(kingStartCol) : 0;
        if (lane != null)
            base = lane.base;
        return {
            startCol: lane == null ? -1 : (side == "kingside" ? lane.kingRookHomeCol : lane.queenRookHomeCol),
            endCol: destRookCol(base, side)
        };
    }

    public function canCastle(color:String, side:String, board:Array<Array<String>>, ?kingStartCol:Int):Bool {
        if (board == null)
            return false;
        if (!config.GameConfig.CASTLING_ENABLED)
            return false;
        if (side != "kingside" && side != "queenside")
            return false;

        var lane = getLane(color, side, board, kingStartCol);
        if (lane == null)
            return false;

        var rowIdx = homeRowFor(color, board);
        if (rowIdx < 0 || rowIdx >= board.length)
            return false;
        var row = board[rowIdx];
        if (row == null)
            return false;

        var kingCol = lane.kingHomeCol;
        var rookCol = side == "kingside" ? lane.kingRookHomeCol : lane.queenRookHomeCol;
        if (rookCol < 0)
            return false;

        if (lane.kingMoved || (side == "kingside" ? lane.kingRookMoved : lane.queenRookMoved))
            return false;
        if (kingCol < 0 || kingCol >= row.length || rookCol < 0 || rookCol >= row.length)
            return false;
        if (row[kingCol] != "king-" + color || row[rookCol] != "rook-" + color)
            return false;

        var kingDest = destKingCol(lane.base, side);
        var rookDest = destRookCol(lane.base, side);
        if (kingDest < 0 || kingDest >= row.length || rookDest < 0 || rookDest >= row.length)
            return false;

        if (!isPathClear(row, kingCol, kingDest, rookCol, -1))
            return false;
        if (!isPathClear(row, rookCol, rookDest, kingCol, -1))
            return false;

        if (isSquareAttackedByEnemy(color, rowIdx, kingCol, board))
            return false;

        for (c in kingPathSquares(kingCol, kingDest)) {
            var test = BoardUtils.copyBoard(board);
            test[rowIdx][kingCol] = "";
            test[rowIdx][rookCol] = "";
            test[rowIdx][c] = "king-" + color;
            test[rowIdx][rookDest] = "rook-" + color;
            if (isSquareAttackedByEnemy(color, rowIdx, c, test))
                return false;
        }

        return true;
    }

    public function getCastlingMoves(color:String, board:Array<Array<String>>, ?kingStartCol:Int):Array<Point> {
        var out:Array<Point> = [];
        var rowIdx = homeRowFor(color, board);
        var lane = getLane(color, "kingside", board, kingStartCol);
        var base = lane != null ? lane.base : (kingStartCol != null ? segmentBase(kingStartCol) : 0);
        if (canCastle(color, "kingside", board, kingStartCol))
            out.push(new Point(destKingCol(base, "kingside"), rowIdx));
        if (canCastle(color, "queenside", board, kingStartCol))
            out.push(new Point(destKingCol(base, "queenside"), rowIdx));
        return out;
    }

    public function executeCastling(color:String, side:String, board:Array<Array<String>>, ?kingStartCol:Int):Void {
        var lane = getLane(color, side, board, kingStartCol);
        if (lane == null)
            return;
        var rowIdx = homeRowFor(color, board);
        if (rowIdx < 0 || rowIdx >= board.length)
            return;
        if (board[rowIdx] == null)
            return;

        var kingCol = lane.kingHomeCol;
        var rookCol = side == "kingside" ? lane.kingRookHomeCol : lane.queenRookHomeCol;
        var kingDest = destKingCol(lane.base, side);
        var rookDest = destRookCol(lane.base, side);

        var kingPiece = board[rowIdx][kingCol];
        var rookPiece = board[rowIdx][rookCol];
        board[rowIdx][kingCol] = "";
        board[rowIdx][rookCol] = "";
        board[rowIdx][kingDest] = kingPiece;
        board[rowIdx][rookDest] = rookPiece;

        lane.kingMoved = true;
        if (side == "kingside")
            lane.kingRookMoved = true;
        else
            lane.queenRookMoved = true;
    }

    public function markPieceMoved(pieceId:String, col:Int, row:Int, ?board:Array<Array<String>>):Void {
        if (board != null)
            discoverAllIfNeeded(board);
        var p = BoardUtils.parsePieceId(pieceId);
        var lanes = lanesFor(p.color);
        if (lanes == null)
            return;

        if (row != homeRowFor(p.color, board))
            return;

        if (p.type == "king") {
            for (lane in lanes)
                if (lane.kingHomeCol == col)
                    lane.kingMoved = true;
            return;
        }

        if (p.type == "rook") {
            for (lane in lanes) {
                if (lane.queenRookHomeCol == col)
                    lane.queenRookMoved = true;
                if (lane.kingRookHomeCol == col)
                    lane.kingRookMoved = true;
            }
        }
    }

    function primaryLane(color:String, board:Array<Array<String>>):CastlingLane {
        discoverLanesIfNeeded(color, board);
        var lanes = lanesFor(color);
        if (lanes == null || lanes.length == 0)
            return null;
        for (lane in lanes)
            if (lane.base == 0)
                return lane;
        return lanes[0];
    }

    public function getInitialCastlingRightsFEN(board:Array<Array<String>>):String {
        if (!config.GameConfig.CASTLING_ENABLED)
            return "-";
        if (board.length != 8 || (board.length > 0 && board[0].length != 8))
            return "-";

        var s = "";
        var wr = board.length - 1;
        var br = 0;
        var w = primaryLane("w", board);
        var b = primaryLane("b", board);
        if (w != null) {
            if (w.kingRookHomeCol >= 0 && board[wr][w.kingHomeCol] == "king-w" && board[wr][w.kingRookHomeCol] == "rook-w")
                s += "K";
            if (w.queenRookHomeCol >= 0 && board[wr][w.kingHomeCol] == "king-w" && board[wr][w.queenRookHomeCol] == "rook-w")
                s += "Q";
        }
        if (b != null) {
            if (b.kingRookHomeCol >= 0 && board[br][b.kingHomeCol] == "king-b" && board[br][b.kingRookHomeCol] == "rook-b")
                s += "k";
            if (b.queenRookHomeCol >= 0 && board[br][b.kingHomeCol] == "king-b" && board[br][b.queenRookHomeCol] == "rook-b")
                s += "q";
        }
        return s != "" ? s : "-";
    }

    public function getCastlingRightsFEN(board:Array<Array<String>>):String {
        if (!config.GameConfig.CASTLING_ENABLED)
            return "-";
        if (board.length != 8 || (board.length > 0 && board[0].length != 8))
            return "-";

        var s = "";
        var wr = board.length - 1;
        var br = 0;
        var w = primaryLane("w", board);
        var b = primaryLane("b", board);
        if (w != null) {
            if (!w.kingMoved && !w.kingRookMoved && board[wr][w.kingHomeCol] == "king-w" && board[wr][w.kingRookHomeCol] == "rook-w")
                s += "K";
            if (!w.kingMoved && !w.queenRookMoved && board[wr][w.kingHomeCol] == "king-w" && board[wr][w.queenRookHomeCol] == "rook-w")
                s += "Q";
        }
        if (b != null) {
            if (!b.kingMoved && !b.kingRookMoved && board[br][b.kingHomeCol] == "king-b" && board[br][b.kingRookHomeCol] == "rook-b")
                s += "k";
            if (!b.kingMoved && !b.queenRookMoved && board[br][b.kingHomeCol] == "king-b" && board[br][b.queenRookHomeCol] == "rook-b")
                s += "q";
        }
        return s != "" ? s : "-";
    }

    public function resetAll():Void {
        whiteLanes = null;
        blackLanes = null;
        pendingFenCastle = null;
    }

    public function applyCastlingFromFEN(fenCastle:String):Void {
        resetAll();
        if (fenCastle == null || fenCastle == "" || fenCastle == "-")
            return;
        pendingFenCastle = fenCastle;
    }
}