package controllers;

import openfl.geom.Point;
import interfaces.IGameController;
import managers.BoardManager;
import managers.ValidationManager;
import pieces.PieceFactory;
import interfaces.IPiece;
import managers.CastlingManager;
import ui.PromotionMenu;

/**
 * Main game controller implementing IGameController
 * Coordinates between board state, validation, and game logic
 */
class GameController implements IGameController {
    private var boardManager:BoardManager;
    private var gameState:String;
    private var promotionMenu:PromotionMenu;
    private var onPromotionCompleted:Void->Void;
    
    public function new() {
        // Initialize piece factory with standard pieces
        PieceFactory.init();
        new CastlingManager();
        
        // Create board with standard layout (could be made configurable)
        var layout = config.BoardLayout.getClassicLayout();
        this.boardManager = new BoardManager(layout);
        this.gameState = "active";
    }
    
    public function getBoardData():Array<Array<String>> {
        return boardManager.getBoardData();
    }
    
    public function getCurrentTurn():String {
        return boardManager.getCurrentTurn();
    }
    
    public function getSelectedTile():Point {
        return boardManager.getSelectedTile();
    }
    
    public function handleSelect(col:Int, row:Int):Bool {
        return boardManager.handleSelect(col, row);
    }
    
    public function attemptMove(col:Int, row:Int):Bool {
        var startPos = boardManager.getSelectedTile();
        if (startPos == null) return false;
        
        var endPos = new Point(col, row);
        var pieceStr = boardManager.getPieceAt(Std.int(startPos.x), Std.int(startPos.y));
        var piece:IPiece = PieceFactory.createPiece(pieceStr);
        
        // Null check to prevent crashes if piece creation fails
        if (piece == null) {
            boardManager.setSelectedTile(null);
            return false;
        }
        
        if (ValidationManager.isValidMove(piece, startPos, endPos, boardManager.getBoardData())) {
            // Check if this move results in promotion
            if (boardManager.checkNeedsPromotion(startPos, endPos)) {
                // Store the pending move and show promotion menu
                boardManager.setPendingPromotion(startPos, endPos);
                boardManager.setSelectedTile(null);
                
                if (promotionMenu == null) {
                    promotionMenu = new PromotionMenu();
                }
                promotionMenu.show(onPromotionSelected, getCurrentTurn());
                
                return true;
            }
            
            // Not a promotion - complete the move normally
            boardManager.executeMove(startPos, endPos);
            
            // Clear the selected tile after move
            boardManager.setSelectedTile(null);
            
            // Switch turn to the next player
            boardManager.switchTurn();
            
            // Update game state for the new current player
            gameState = ValidationManager.getGameState(getCurrentTurn(), getBoardData());
            
            // Check for game over
            if (gameState == "checkmate") {
                trace("Game Over: Checkmate!");
            } else if (gameState == "stalemate") {
                trace("Game Over: Stalemate!");
            } else if (gameState == "check") {
                trace("Check!");
            }
            
            return true;
        }
        
        boardManager.setSelectedTile(null);
        return false;
    }
    
    public function getLegalMovesForSelection():Array<Point> {
        var selected = boardManager.getSelectedTile();
        if (selected == null) return [];
        
        var moves:Array<Point> = [];
        var pieceStr = boardManager.getPieceAt(Std.int(selected.x), Std.int(selected.y));
        var piece:IPiece = PieceFactory.createPiece(pieceStr);
        
        // Check every tile to see if it's a legal move
        for (r in 0...8) {
            for (c in 0...8) {
                var target = new Point(c, r);
                if (ValidationManager.isValidMove(piece, selected, target, boardManager.getBoardData())) {
                    moves.push(target);
                }
            }
        }
        
        return moves;
    }
    
    public function getGameState():String {
        return gameState;
    }
    
    /**
     * Called when player selects a promotion piece
     */
    private function onPromotionSelected(pieceType:String):Void {
        boardManager.completePendingPromotion(pieceType);
        
        // Now complete the turn
        boardManager.switchTurn();
        gameState = ValidationManager.getGameState(getCurrentTurn(), getBoardData());
        
        // Check for game over
        if (gameState == "checkmate") {
            trace("Game Over: Checkmate!");
        } else if (gameState == "stalemate") {
            trace("Game Over: Stalemate!");
        } else if (gameState == "check") {
            trace("Check!");
        }
        
        // Trigger the completion callback so Main can re-render
        if (onPromotionCompleted != null) {
            onPromotionCompleted();
        }
    }
    
    /**
     * Set the callback for when promotion is completed
     */
    public function setOnPromotionCompleted(callback:Void->Void):Void {
        onPromotionCompleted = callback;
    }
    
    /**
     * Get the promotion menu for adding to the stage
     */
    public function getPromotionMenu():PromotionMenu {
        if (promotionMenu == null) {
            promotionMenu = new PromotionMenu();
        }
        return promotionMenu;
    }
    
    /**
     * Check if there's a pending promotion
     */
    public function isPendingPromotion():Bool {
        return boardManager.isPendingPromotion();
    }
}