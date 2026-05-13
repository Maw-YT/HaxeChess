package managers;

import openfl.geom.Point;
import interfaces.IGameController;
import config.GameConfig;
import pieces.PieceFactory;
import utils.BoardUtils;
import utils.ChessNotation;

/**
 * Manages the board state and move validation
 */
class BoardManager {
    private var boardData:Array<Array<String>>;
    /** Half-move log in UCI (e.g. e2e4, e7e8q). White, black, white, ... */
    private var moveHistory:Array<String>;
    private var currentTurn:String;
    private var selectedTile:Point;
    private var lastMoveStart:Point;
    private var lastMoveEnd:Point;
    private var lastMovedPiece:String;
    
    private var pendingPromotionStart:Point;
    private var pendingPromotionEnd:Point;

    /** FEN en passant target square (e.g. e3) or "-" after the last half-move. */
    private var epTargetFEN:String = "-";
    
    public static var instance:BoardManager;
    
    public function new(layout:Array<Array<String>>) {
        this.boardData = utils.BoardUtils.copyBoard(layout);
        GameConfig.syncFromBoard(this.boardData);
        this.moveHistory = [];
        this.currentTurn = "w";
        this.selectedTile = null;
        this.lastMoveStart = null;
        this.lastMoveEnd = null;
        this.lastMovedPiece = "";
        this.pendingPromotionStart = null;
        this.pendingPromotionEnd = null;
        instance = this;
    }
    
    public function getBoardData():Array<Array<String>> {
        return boardData;
    }
    
    public function getCurrentTurn():String {
        return currentTurn;
    }
    
    public function getSelectedTile():Point {
        return selectedTile;
    }
    
    public function setSelectedTile(tile:Point):Void {
        this.selectedTile = tile;
    }
    
    /**
     * Get the last move's starting position (for en passant)
     */
    public function getLastMoveStart():Point {
        return lastMoveStart;
    }
    
    /**
     * Get the last move's ending position (for en passant)
     */
    public function getLastMoveEnd():Point {
        return lastMoveEnd;
    }
    
    /**
     * Get the piece that was moved last (for en passant)
     */
    public function getLastMovedPiece():String {
        return lastMovedPiece;
    }

    public function getEpTargetFEN():String {
        return epTargetFEN;
    }
    
    /**
     * Switch to the next player's turn
     */
    public function switchTurn():Void {
        currentTurn = (currentTurn == "w") ? "b" : "w";
    }
    
    public function handleSelect(col:Int, row:Int):Bool {
        // Handle invalid coordinates - clear selection
        if (col < 0 || row < 0 || col >= GameConfig.boardCols || row >= GameConfig.boardRows) {
            selectedTile = null;
            return false;
        }
        
        var pieceStr = boardData[row][col];
        if (pieceStr != "" && BoardUtils.isPieceOfColor(pieceStr, currentTurn)) {
            selectedTile = new Point(col, row);
            return true;
        }
        return false;
    }

    /** Select any non-empty square (used when illegal moves are allowed). */
    public function handleSelectAnyPiece(col:Int, row:Int):Bool {
        if (col < 0 || row < 0 || col >= GameConfig.boardCols || row >= GameConfig.boardRows) {
            selectedTile = null;
            return false;
        }
        var pieceStr = boardData[row][col];
        if (pieceStr != "") {
            selectedTile = new Point(col, row);
            return true;
        }
        selectedTile = null;
        return false;
    }

    /**
     * UPDATED: Handles standard moves, promotion, castling, and en passant
     */
    public function executeMove(startPos:Point, endPos:Point):Void {
        var startX = Std.int(startPos.x);
        var startY = Std.int(startPos.y);
        var endX = Std.int(endPos.x);
        var endY = Std.int(endPos.y);
        
        var startCell = BoardUtils.cellAt(boardData, startY, startX);
        var endCell = BoardUtils.cellAt(boardData, endY, endX);
        if (startCell == null || endCell == null)
            return;
        var pieceStr = startCell;
        if (pieceStr == "") return;
        
        var parsed = BoardUtils.parsePieceId(pieceStr);
        var movingPiece = PieceFactory.createPiece(pieceStr);
        
        // 1. Castling only when legal for this king (not merely landing on c/g).
        var isCastling = false;
        var castlingSide:String = null;
        if (parsed.type == "king" && endCell == "" && managers.CastlingManager.instance != null) {
            castlingSide = managers.CastlingManager.instance.getCastlingSideIfMove(parsed.color, boardData, startX, startY, endX, endY);
        }
        if (castlingSide != null) {
            isCastling = true;
            managers.CastlingManager.instance.executeCastling(parsed.color, castlingSide, boardData, startX);
        }
        
        // 2. Check for En Passant capture - now uses canEnPassant()
        var isEnPassant = false;
        if (movingPiece != null && movingPiece.canEnPassant() && boardData[endY][endX] == "" && startX != endX) {
            if (lastMoveEnd != null && lastMovedPiece != "" && lastMoveEnd.x == endX) {
                var lastPiece = PieceFactory.createPiece(lastMovedPiece);
                if (lastPiece != null && lastPiece.canEnPassant()) {
                    var lastParsed = BoardUtils.parsePieceId(lastMovedPiece);
                    if (lastParsed.color != parsed.color) {
                        var moveDistance = Math.abs(Std.int(lastMoveEnd.y) - Std.int(lastMoveStart.y));
                        if (moveDistance == 2) {
                            var captureRow = Std.int(lastMoveEnd.y);
                            boardData[captureRow][endX] = "";
                            isEnPassant = true;
                        }
                    }
                }
            }
        }
        
        // 3. Standard Move Logic
        if (!isCastling) {
            // Update move history so they can't castle later
            if (managers.CastlingManager.instance != null) {
                managers.CastlingManager.instance.markPieceMoved(pieceStr, startX, startY, boardData);
            }
            
            boardData[endY][endX] = pieceStr;
            boardData[startY][startX] = "";
        }
        
        // 4. Record this move for en passant detection on the next turn
        if (parsed.type == "pawn" || parsed.type == "royalpawn") {
            lastMoveStart = new Point(startX, startY);
            lastMoveEnd = new Point(endX, endY);
            lastMovedPiece = pieceStr;
        }

        if (isCastling) {
            epTargetFEN = "-";
        } else if ((parsed.type == "pawn" || parsed.type == "royalpawn") && Math.abs(endY - startY) == 2) {
            var midRow = Std.int((startY + endY) / 2);
            epTargetFEN = ChessNotation.colToFile(endX) + ChessNotation.rowToRank(midRow);
        } else {
            epTargetFEN = "-";
        }
    }
    
    /**
     * Check if a move from start to end would result in pawn promotion
     */
    public function checkNeedsPromotion(startPos:Point, endPos:Point):Bool {
        var startY = Std.int(startPos.y);
        var endY = Std.int(endPos.y);
        
        var pieceStr = boardData[startY][Std.int(startPos.x)];
        if (pieceStr == "") return false;
        
        var parsed = BoardUtils.parsePieceId(pieceStr);
        if (parsed.type != "pawn" && parsed.type != "royalpawn") return false;

        var lastRow = boardData.length - 1;
        var isPromotionRow = (parsed.color == "w" && endY == 0) || (parsed.color == "b" && endY == lastRow);
        return isPromotionRow;
    }
    
    /**
     * Store a pending promotion move
     */
    public function setPendingPromotion(startPos:Point, endPos:Point):Void {
        pendingPromotionStart = startPos;
        pendingPromotionEnd = endPos;
    }
    
    /**
     * Check if there's a pending promotion
     */
    public function isPendingPromotion():Bool {
        return pendingPromotionStart != null && pendingPromotionEnd != null;
    }
    
    /**
     * Complete the pending promotion with the chosen piece type
     */
    public function completePendingPromotion(pieceType:String):Void {
        if (!isPendingPromotion()) return;
        
        var startX = Std.int(pendingPromotionStart.x);
        var startY = Std.int(pendingPromotionStart.y);
        var endX = Std.int(pendingPromotionEnd.x);
        var endY = Std.int(pendingPromotionEnd.y);
        
        var pieceStr = boardData[startY][startX];
        if (pieceStr == "") return;
        
        var parsed = BoardUtils.parsePieceId(pieceStr);
        
        // Move the pawn and promote it
        var promotedPiece = pieceType + "-" + parsed.color;
        boardData[endY][endX] = promotedPiece;
        boardData[startY][startX] = "";
        
        // Update move history
        if (managers.CastlingManager.instance != null) {
            managers.CastlingManager.instance.markPieceMoved(pieceStr, startX, startY, boardData);
        }
        
        // Record this move for en passant
        lastMoveStart = new Point(startX, startY);
        lastMoveEnd = new Point(endX, endY);
        lastMovedPiece = promotedPiece;
        
        recordHalfMove(startX, startY, endX, endY, ChessNotation.promotionToUCI(pieceType));

        // Clear pending promotion
        pendingPromotionStart = null;
        pendingPromotionEnd = null;

        epTargetFEN = "-";
    }
    
    /**
     * Get a piece at the given position
     */
    public function getPieceAt(col:Int, row:Int):String {
        return boardData[row][col];
    }

    /**
     * Record one completed half-move (call after the position is updated).
     */
    public function recordHalfMove(fromCol:Int, fromRow:Int, toCol:Int, toRow:Int, ?promotionUci:String = ""):Void {
        var uci = ChessNotation.toUCI(fromCol, fromRow, toCol, toRow, promotionUci != null ? promotionUci : "");
        moveHistory.push(uci);
    }

    public function getMoveHistory():Array<String> {
        return moveHistory.copy();
    }

    /** Replace move log (e.g. after replaying a prefix for history view). */
    public function setMoveHistory(h:Array<String>):Void {
        moveHistory = h.copy();
    }

    /** Replace board and reset transient game state (new game / reset from settings). */
    public function resetToLayout(layout:Array<Array<String>>, whiteToMove:Bool):Void {
        boardData = BoardUtils.copyBoard(layout);
        moveHistory = [];
        currentTurn = whiteToMove ? "w" : "b";
        selectedTile = null;
        lastMoveStart = null;
        lastMoveEnd = null;
        lastMovedPiece = "";
        pendingPromotionStart = null;
        pendingPromotionEnd = null;
        epTargetFEN = "-";
        GameConfig.syncFromBoard(boardData);
    }

    /** Set square contents (e.g. illegal UCI promotion placement). */
    public function setPieceAt(col:Int, row:Int, pieceId:String):Void {
        if (col < 0 || row < 0 || col >= GameConfig.boardCols || row >= GameConfig.boardRows)
            return;
        boardData[row][col] = (pieceId == null || pieceId == "") ? "" : pieceId;
    }

    /**
     * Move without castling/en passant (illegal-move mode or simple relocations).
     */
    public function executeRelocateOnly(startPos:Point, endPos:Point):Void {
        var startX = Std.int(startPos.x);
        var startY = Std.int(startPos.y);
        var endX = Std.int(endPos.x);
        var endY = Std.int(endPos.y);
        var pieceStr = boardData[startY][startX];
        if (pieceStr == "")
            return;
        var parsed = BoardUtils.parsePieceId(pieceStr);
        if (managers.CastlingManager.instance != null)
            CastlingManager.instance.markPieceMoved(pieceStr, startX, startY, boardData);
        boardData[endY][endX] = pieceStr;
        boardData[startY][startX] = "";
        if (parsed.type == "pawn" || parsed.type == "royalpawn") {
            lastMoveStart = new Point(startX, startY);
            lastMoveEnd = new Point(endX, endY);
            lastMovedPiece = pieceStr;
            if (Math.abs(endY - startY) == 2) {
                var midRow = Std.int((startY + endY) / 2);
                epTargetFEN = ChessNotation.colToFile(endX) + ChessNotation.rowToRank(midRow);
            } else {
                epTargetFEN = "-";
            }
        } else {
            lastMoveStart = null;
            lastMoveEnd = null;
            lastMovedPiece = "";
            epTargetFEN = "-";
        }
    }
}
