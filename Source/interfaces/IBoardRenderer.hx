package interfaces;

import openfl.geom.Point;

/**
 * Interface for board rendering
 */
interface IBoardRenderer {
    /**
     * Render the board with optional selection and move hints
     */
    function render(?selectedTile:Point, ?hints:Array<Point>, ?captureHints:Array<Point>, ?lastMoveFrom:Point, ?lastMoveTo:Point):Void;
    
    /**
     * Clear all highlights
     */
    function clearHighlights():Void;
    
    /**
     * Get the tile size
     */
    function getTileSize():Int;

    /** Resize the board grid (integer pixels); caller should call `render` after. */
    function setTileSize(size:Int):Void;
    
    /**
     * Set which royal pieces are in check (to draw red gradient behind them)
     */
    function setCheckHighlights(royalPositions:Array<Point>):Void;
}