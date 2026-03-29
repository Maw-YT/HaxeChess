package interfaces;

import openfl.geom.Point;
import ui.PromotionMenu;

/**
 * Interface for game controller
 * Defines the core game logic operations
 */
interface IGameController {
    /**
     * Get the current board data
     */
    function getBoardData():Array<Array<String>>;
    
    /**
     * Get the current turn ("w" or "b")
     */
    function getCurrentTurn():String;
    
    /**
     * Get the currently selected tile
     */
    function getSelectedTile():Point;
    
    /**
     * Handle a tile selection
     * Returns true if a piece was selected
     */
    function handleSelect(col:Int, row:Int):Bool;
    
    /**
     * Attempt to move a piece
     * Returns true if the move was successful
     */
    function attemptMove(col:Int, row:Int):Bool;
    
    /**
     * Get all legal moves for the currently selected piece
     */
    function getLegalMovesForSelection():Array<Point>;
    
    /**
     * Get the current game state
     */
    function getGameState():String;
    
    /**
     * Get the promotion menu for UI display
     */
    function getPromotionMenu():PromotionMenu;
    
    /**
     * Check if there's a pending promotion
     */
    function isPendingPromotion():Bool;
    
    /**
     * Set the callback for when promotion is completed
     */
    function setOnPromotionCompleted(callback:Void->Void):Void;
}