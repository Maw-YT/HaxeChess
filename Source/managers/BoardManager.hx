package managers;

import openfl.geom.Point;
import interfaces.IGameController;
import config.GameConfig;
import pieces.PieceFactory;
import utils.BoardUtils;

/**
 * Manages the board state and move validation
 */
class BoardManager {
    private var boardData:Array<Array<String>>;
    private var currentTurn:String;
    private var selectedTile:Point;
    private var lastMoveStart:Point;
    private var lastMoveEnd:Point;
    private var lastMovedPiece:String;
    
    private var pendingPromotionStart:Point;
    private var pendingPromotionEnd:Point;
    
    public static var instance:BoardManager;
    
    public function new(layout:Array<Array<String>>) {
        this.boardData = utils.BoardUtils.copyBoard(layout);
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
    
    /**
     * Switch to the next player's turn
     */
    public function switchTurn():Void {
        currentTurn = (currentTurn == "w") ? "b" : "w";
    }
    
    public function handleSelect(col:Int, row:Int):Bool {
        var pieceStr = boardData[row][col];
        if (pieceStr != "" && BoardUtils.isPieceOfColor(pieceStr, currentTurn)) {
            selectedTile = new Point(col, row);
            return true;
        }
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
        
        var pieceStr = boardData[startY][startX];
        if (pieceStr == "") return;
        
        var parsed = BoardUtils.parsePieceId(pieceStr);
        
        // 1. Check for Castling (King moves 2 spaces sideways)
        var isCastling = false;
        if (parsed.type == "king" && Math.abs(endX - startX) == 2) {
            isCastling = true;
            var side = (endX > startX) ? "kingside" : "queenside";
            
            if (managers.CastlingManager.instance != null) {
                // This moves BOTH the King and the Rook
                managers.CastlingManager.instance.executeCastling(parsed.color, side, boardData);
            }
        }
        
        // 2. Check for En Passant capture
        var isEnPassant = false;
        if (parsed.type == "pawn" && boardData[endY][endX] == "" && startX != endX) {
            if (lastMoveEnd != null && lastMovedPiece != "" && lastMoveEnd.x == endX) {
                var lastParsed = BoardUtils.parsePieceId(lastMovedPiece);
                if (lastParsed.type == "pawn" && lastParsed.color != parsed.color) {
                    var moveDistance = Math.abs(Std.int(lastMoveEnd.y) - Std.int(lastMoveStart.y));
                    if (moveDistance == 2) {
                        var captureRow = Std.int(lastMoveEnd.y);
                        boardData[captureRow][endX] = "";
                        isEnPassant = true;
                    }
                }
            }
        }
        
        // 3. Standard Move Logic
        if (!isCastling) {
            // Update move history so they can't castle later
            if (managers.CastlingManager.instance != null) {
                managers.CastlingManager.instance.markPieceMoved(pieceStr, startX, startY);
            }
            
            boardData[endY][endX] = pieceStr;
            boardData[startY][startX] = "";
        }
        
        // 4. Record this move for en passant detection on the next turn
        // Only update en passant tracking when a pawn moves (to make it persist indefinitely)
        if (parsed.type == "pawn") {
            lastMoveStart = new Point(startX, startY);
            lastMoveEnd = new Point(endX, endY);
            lastMovedPiece = pieceStr;
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
        if (parsed.type != "pawn") return false;
        
        var isPromotionRow = (parsed.color == "w" && endY == 0) || (parsed.color == "b" && endY == 7);
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
            managers.CastlingManager.instance.markPieceMoved(pieceStr, startX, startY);
        }
        
        // Record this move for en passant
        lastMoveStart = new Point(startX, startY);
        lastMoveEnd = new Point(endX, endY);
        lastMovedPiece = promotedPiece;
        
        // Clear pending promotion
        pendingPromotionStart = null;
        pendingPromotionEnd = null;
    }
    
    /**
     * Get a piece at the given position
     */
    public function getPieceAt(col:Int, row:Int):String {
        return boardData[row][col];
    }
}
