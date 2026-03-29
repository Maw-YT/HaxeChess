package interfaces;

import openfl.geom.Point;

/**
 * Interface for board rendering
 * Allows for different rendering strategies
 */
interface IBoardRenderer {
    /**
     * Render the board with optional selection and hints
     */
    function render(?selectedTile:Point, ?hints:Array<Point>):Void;
    
    /**
     * Clear all highlights
     */
    function clearHighlights():Void;
    
    /**
     * Get the tile size
     */
    function getTileSize():Int;
}