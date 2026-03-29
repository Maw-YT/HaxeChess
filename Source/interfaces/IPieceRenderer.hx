package interfaces;

/**
 * Interface for piece rendering
 * Allows for different piece rendering strategies (sprites, 3D, etc.)
 */
interface IPieceRenderer {
    /**
     * Render all pieces from the given board data
     */
    function render(boardData:Array<Array<String>>):Void;
    
    /**
     * Animate a piece move from start to end position
     */
    function animateMove(startR:Int, startC:Int, endR:Int, endC:Int, pieceId:String, callback:Void->Void):Void;
    
    /**
     * Animate a castling move (king and rook move simultaneously)
     */
    function animateCastling(kingStartR:Int, kingStartC:Int, kingEndR:Int, kingEndC:Int, 
                            rookStartR:Int, rookStartC:Int, rookEndR:Int, rookEndC:Int, callback:Void->Void):Void;
    
    /**
     * Update a single tile with a new piece
     */
    function updateTile(row:Int, col:Int, newId:String):Void;
    
    /**
     * Clear all pieces
     */
    function clear():Void;
}