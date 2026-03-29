package interfaces;

import openfl.geom.Point;

/**
 * Interface for all piece types
 * Defines the contract that all pieces must follow
 */
interface IPiece {
    /**
     * Get the piece type (e.g., "pawn", "rook", "nuke")
     */
    function getType():String;
    
    /**
     * Get the piece color ("w" or "b")
     */
    function getColor():String;
    
    /**
     * Get the unique ID (e.g., "pawn-w")
     */
    function getId():String;
    
    /**
     * Check if this is a royal piece (king)
     */
    function isRoyal():Bool;
    
    /**
     * Get the piece's value for evaluation
     */
    function getValue():Int;
    
    /**
     * Get all valid non-capture moves from the current position
     */
    function getValidMoves(row:Int, col:Int, board:Array<Array<String>>):Array<Point>;
    
    /**
     * Get all valid capture moves from the current position
     * Useful for pieces that capture differently than they move (like pawns)
     */
    function getCaptureMoves(row:Int, col:Int, board:Array<Array<String>>):Array<Point>;
}