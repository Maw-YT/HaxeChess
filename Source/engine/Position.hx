package engine;

import openfl.geom.Point;
import config.GameConfig;
import managers.ValidationManager;
import pieces.PieceFactory;
import utils.BoardUtils;
import utils.ChessNotation;
import managers.CastlingManager;
import engine.Eval.EvalAccumulator;

typedef EngineMove = {
    var fromCol:Int;
    var fromRow:Int;
    var toCol:Int;
    var toRow:Int;
    var promotion:String;
    var isCastling:Bool;
    var isEnPassant:Bool;
    var capturedPiece:String;
};

typedef UndoSnapshot = {
    var board:Array<Array<String>>;
    var sideToMove:String;
    var lastMoveStart:Null<Point>;
    var lastMoveEnd:Null<Point>;
    var lastMovedPiece:String;
    var acc:EvalAccumulator;
    var castlingMask:Int;
    var epCol:Int;
    var halfmoveClock:Int;
    var fullmoveNumber:Int;
    var zobKey:Int;
};

class Position {
    public var board(default, null):Array<Array<String>>;
    public var sideToMove(default, null):String;
    public var acc(default, null):EvalAccumulator;
    public var castlingMask(default, null):Int;
    public var epCol(default, null):Int;
    public var halfmoveClock(default, null):Int;
    public var fullmoveNumber(default, null):Int;
    public var zobKey(default, null):Int;

    var lastMoveStart:Null<Point>;
    var lastMoveEnd:Null<Point>;
    var lastMovedPiece:String;
    var history:Array<UndoSnapshot> = [];

    public function new(board:Array<Array<String>>, sideToMove:String, ?lastMoveStart:Null<Point>, ?lastMoveEnd:Null<Point>, ?lastMovedPiece:String = "") {
        this.board = BoardUtils.copyBoard(board);
        this.sideToMove = sideToMove;
        this.lastMoveStart = lastMoveStart != null ? new Point(lastMoveStart.x, lastMoveStart.y) : null;
        this.lastMoveEnd = lastMoveEnd != null ? new Point(lastMoveEnd.x, lastMoveEnd.y) : null;
        this.lastMovedPiece = lastMovedPiece != null ? lastMovedPiece : "";
        this.castlingMask = 15;
        this.epCol = -1;
        this.halfmoveClock = 0;
        this.fullmoveNumber = 1;
        GameConfig.syncFromBoard(this.board);
        this.acc = Eval.build(this.board);
        refreshZobKey();
    }

    public function generateLegalMoves():Array<EngineMove> {
        return generateLegalMovesForColor(sideToMove);
    }

    /** Legal moves as if `moverColor` were to move (same board, castling, ep geometry). */
    public function generateLegalMovesForColor(moverColor:String):Array<EngineMove> {
        var out:Array<EngineMove> = [];
        collectOrCountLegalMovesForColor(moverColor, out);
        return out;
    }

    /** Count legal moves for `moverColor` without allocating a move list (for evaluation). */
    public function countLegalMovesForColor(moverColor:String):Int {
        return collectOrCountLegalMovesForColor(moverColor, null);
    }

    function collectOrCountLegalMovesForColor(moverColor:String, out:Null<Array<EngineMove>>):Int {
        var n = 0;
        for (r in 0...board.length) {
            var row = board[r];
            if (row == null)
                continue;
            for (c in 0...row.length) {
                var id = row[c];
                if (id == "" || !BoardUtils.isPieceOfColor(id, moverColor))
                    continue;
                var p = PieceFactory.createPiece(id);
                if (p == null)
                    continue;
                var all = p.getValidMoves(r, c, board).concat(p.getCaptureMoves(r, c, board));
                var seen = new Map<String, Bool>();
                for (m in all) {
                    var toC = Std.int(m.x);
                    var toR = Std.int(m.y);
                    var k = toC + ":" + toR;
                    if (seen.exists(k))
                        continue;
                    seen.set(k, true);
                    if (!ValidationManager.isValidMove(p, new Point(c, r), new Point(toC, toR), board))
                        continue;
                    n++;
                    if (out != null) {
                        var ep = BoardUtils.enPassantCaptureSquare(board, c, r, toC, toR, id);
                        var side:Null<String> = null;
                        var targetCell = BoardUtils.cellAt(board, toR, toC);
                        if (id.indexOf("king") == 0 && targetCell == "" && CastlingManager.instance != null) {
                            side = CastlingManager.instance.getCastlingSideIfMove(BoardUtils.parsePieceId(id).color, board, c, r, toC, toR);
                        }
                        out.push({
                            fromCol: c,
                            fromRow: r,
                            toCol: toC,
                            toRow: toR,
                            promotion: "",
                            isCastling: side != null,
                            isEnPassant: ep != null,
                            capturedPiece: targetCell != null ? targetCell : ""
                        });
                    }
                }
            }
        }
        return n;
    }

    public function generateLegalCaptures():Array<EngineMove> {
        var all = generateLegalMoves();
        var caps:Array<EngineMove> = [];
        for (m in all) {
            if (m.isEnPassant || m.capturedPiece != "")
                caps.push(m);
        }
        return caps;
    }

    public function makeMove(m:EngineMove):Void {
        history.push({
            board: BoardUtils.copyBoard(board),
            sideToMove: sideToMove,
            lastMoveStart: lastMoveStart != null ? new Point(lastMoveStart.x, lastMoveStart.y) : null,
            lastMoveEnd: lastMoveEnd != null ? new Point(lastMoveEnd.x, lastMoveEnd.y) : null,
            lastMovedPiece: lastMovedPiece,
            acc: Eval.clone(acc),
            castlingMask: castlingMask,
            epCol: epCol,
            halfmoveClock: halfmoveClock,
            fullmoveNumber: fullmoveNumber,
            zobKey: zobKey
        });

        var capturedBefore = board[m.toRow][m.toCol];
        var rows = board.length;
        var cols = rows > 0 ? board[0].length : 8;
        var pieceId = board[m.fromRow][m.fromCol];
        var parsed = BoardUtils.parsePieceId(pieceId);
        var oldEp = epCol;
        epCol = -1;
        var needsRebuild = false;
        var castleSide = CastlingManager.instance != null
            ? CastlingManager.instance.getCastlingSideIfMove(parsed.color, board, m.fromCol, m.fromRow, m.toCol, m.toRow)
            : null;
        if (castleSide != null) {
            needsRebuild = true;
            var side = castleSide;
            var base = Std.int(m.fromCol / 8) * 8;
            var rookDest = base + (side == "kingside" ? CastlingManager.KINGSIDE_ROOK_DEST_COL : CastlingManager.QUEENSIDE_ROOK_DEST_COL);
            var step = side == "kingside" ? 1 : -1;
            var rookStart = -1;
            var c = m.fromCol + step;
            var max = base + 7;
            while (c >= base && c <= max) {
                if (board[m.fromRow][c] == "rook-" + parsed.color) {
                    rookStart = c;
                    break;
                }
                c += step;
            }
            board[m.fromRow][m.fromCol] = "";
            if (rookStart >= 0)
                board[m.fromRow][rookStart] = "";
            board[m.toRow][m.toCol] = pieceId;
            if (rookStart >= 0)
                board[m.fromRow][rookDest] = "rook-" + parsed.color;
        } else if (m.isEnPassant) {
            needsRebuild = true;
            board[m.fromRow][m.toCol] = "";
            board[m.toRow][m.toCol] = pieceId;
            board[m.fromRow][m.fromCol] = "";
        } else {
            board[m.toRow][m.toCol] = pieceId;
            board[m.fromRow][m.fromCol] = "";
            Eval.updateNormalMove(acc, pieceId, m.fromRow, m.fromCol, m.toRow, m.toCol, capturedBefore, rows, cols);
        }

        if ((parsed.type == "pawn" || parsed.type == "royalpawn") && m.promotion != null && m.promotion != "") {
            needsRebuild = true;
            board[m.toRow][m.toCol] = ChessNotation.uciToPromotion(m.promotion) + "-" + parsed.color;
        }
        updateCastlingMaskOnMove(pieceId, m.fromRow, m.fromCol, m.toRow, m.toCol, capturedBefore);
        if (needsRebuild)
            acc = Eval.build(board);

        if (parsed.type == "pawn" || parsed.type == "royalpawn") {
            lastMoveStart = new Point(m.fromCol, m.fromRow);
            lastMoveEnd = new Point(m.toCol, m.toRow);
            lastMovedPiece = board[m.toRow][m.toCol];
            if (Math.abs(m.toRow - m.fromRow) == 2)
                epCol = m.toCol;
        } else {
            lastMoveStart = null;
            lastMoveEnd = null;
            lastMovedPiece = "";
        }
        if (parsed.type == "pawn" || parsed.type == "royalpawn" || capturedBefore != "" || m.isEnPassant)
            halfmoveClock = 0;
        else
            halfmoveClock++;
        if (sideToMove == "b")
            fullmoveNumber++;
        sideToMove = sideToMove == "w" ? "b" : "w";
        refreshZobKey();
    }

    public function unmakeMove():Void {
        if (history.length == 0)
            return;
        var snap = history.pop();
        board = BoardUtils.copyBoard(snap.board);
        sideToMove = snap.sideToMove;
        lastMoveStart = snap.lastMoveStart != null ? new Point(snap.lastMoveStart.x, snap.lastMoveStart.y) : null;
        lastMoveEnd = snap.lastMoveEnd != null ? new Point(snap.lastMoveEnd.x, snap.lastMoveEnd.y) : null;
        lastMovedPiece = snap.lastMovedPiece;
        acc = Eval.clone(snap.acc);
        castlingMask = snap.castlingMask;
        epCol = snap.epCol;
        halfmoveClock = snap.halfmoveClock;
        fullmoveNumber = snap.fullmoveNumber;
        zobKey = snap.zobKey;
        GameConfig.syncFromBoard(board);
    }

    public function makeNullMove():Void {
        history.push({
            board: BoardUtils.copyBoard(board),
            sideToMove: sideToMove,
            lastMoveStart: lastMoveStart != null ? new Point(lastMoveStart.x, lastMoveStart.y) : null,
            lastMoveEnd: lastMoveEnd != null ? new Point(lastMoveEnd.x, lastMoveEnd.y) : null,
            lastMovedPiece: lastMovedPiece,
            acc: Eval.clone(acc),
            castlingMask: castlingMask,
            epCol: epCol,
            halfmoveClock: halfmoveClock,
            fullmoveNumber: fullmoveNumber,
            zobKey: zobKey
        });
        sideToMove = sideToMove == "w" ? "b" : "w";
        lastMoveStart = null;
        lastMoveEnd = null;
        lastMovedPiece = "";
        epCol = -1;
        halfmoveClock++;
        if (sideToMove == "w")
            fullmoveNumber++;
        acc = Eval.build(board);
        refreshZobKey();
    }

    public function toKey():String {
        return Std.string(zobKey) + "|" + sideToMove + "|" + castlingMask + "|" + epCol + "|" + halfmoveClock;
    }

    /**
     * FIDE-style repetition identity: placement + side + castling + ep (see `Zobrist.hash`).
     * Excludes halfmove / fullmove so in-search shuffles match across reversible-move paths.
     */
    public function repetitionPathKey():String {
        return Std.string(zobKey);
    }

    function refreshZobKey():Void {
        zobKey = Zobrist.hash(board, sideToMove, castlingMask, epCol);
    }

    inline function clearCastleBit(bit:Int):Void {
        castlingMask &= ~bit;
    }

    function updateCastlingMaskOnMove(pieceId:String, fromR:Int, fromC:Int, toR:Int, toC:Int, capturedPiece:String):Void {
        var p = BoardUtils.parsePieceId(pieceId);
        var rows = board.length;
        var cols = rows > 0 && board[0] != null ? board[0].length : 8;
        var whiteBack = rows - 1;
        var blackBack = 0;
        if (p.type == "king") {
            if (p.color == "w") {
                clearCastleBit(1);
                clearCastleBit(2);
            } else {
                clearCastleBit(4);
                clearCastleBit(8);
            }
        } else if (p.type == "rook") {
            if (p.color == "w" && fromR == whiteBack) {
                if (fromC == 0)
                    clearCastleBit(2);
                if (fromC == cols - 1)
                    clearCastleBit(1);
            } else if (p.color == "b" && fromR == blackBack) {
                if (fromC == 0)
                    clearCastleBit(8);
                if (fromC == cols - 1)
                    clearCastleBit(4);
            }
        }
        if (capturedPiece != "") {
            var cp = BoardUtils.parsePieceId(capturedPiece);
            if (cp.type == "rook") {
                if (cp.color == "w" && toR == whiteBack) {
                    if (toC == 0)
                        clearCastleBit(2);
                    if (toC == cols - 1)
                        clearCastleBit(1);
                } else if (cp.color == "b" && toR == blackBack) {
                    if (toC == 0)
                        clearCastleBit(8);
                    if (toC == cols - 1)
                        clearCastleBit(4);
                }
            }
        }
    }
}
