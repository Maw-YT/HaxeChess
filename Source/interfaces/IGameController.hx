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
     * Get all capture moves for the currently selected piece
     */
    function getCaptureMovesForSelection():Array<Point>;
    
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

    
    /**
     * Get the positions of royal pieces that are in check
     */
    function getCheckedRoyals():Array<Point>;
        
    /**
     * Check if a position has a piece (for detecting captures)
     */
    function hasPieceAt(col:Int, row:Int):Bool;

    /**
     * Set square contents directly (used for illegal-mode piece placement)
     */
    function setPieceAt(col:Int, row:Int, pieceId:String):Void;
        
    /**
     * Execute a move from UCI notation (for engine moves)
     */
    function executeUCIMove(uciMove:String):Bool;
    
    /**
     * Get the board's FEN string
     */
    function getFEN():String;

    /**
     * Get engine-safe FEN string.
     */
    function getEngineFEN():String;

    /**
     * Engine-safe FEN for the current game's starting position.
     */
    function getEngineStartFEN():String;

    /**
     * Half-move history in UCI (e2e4, e7e5, …)
     */
    function getMoveHistory():Array<String>;

    /** True when viewing an earlier position (arrow keys); input should be disabled. */
    function isBrowsingHistory():Bool;

    /** Step move-history view: delta -1 = older, +1 = newer. */
    function stepHistoryView(delta:Int):Void;

    /** Half-moves applied for the current history view (0 … getMoveHistory().length). */
    function getHistoryViewPly():Int;

    /** Start square of the last half-move for the current history view (board x=col, y=row). */
    function getLastMoveHighlightFrom():Null<Point>;

    /** End square of the last half-move for the current history view. */
    function getLastMoveHighlightTo():Null<Point>;

    /** Reload starting position from SettingsConfig.boardLayoutId and clear the game. */
    function applySavedBoardLayout():Void;
}