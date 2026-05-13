package interfaces;

/**
 * Interface for piece rendering
 * Allows for different piece rendering strategies (sprites, 3D, etc.)
 */
interface IPieceRenderer {
    /**
     * Render all pieces from the given board data.
     * @param animateSpawns only for a full “deal” (e.g. first paint after layout); false for selection / move sync.
     */
    function render(boardData:Array<Array<String>>, animateSpawns:Bool = false):Void;
    
    /**
     * Animate a piece move from start to end position.
     * Capture / en-passant death tweens run in parallel with the mover (click: slide + deaths; drag: snap + deaths).
     * For en passant, pass the captured pawn's row/col.
     */
    function animateMove(startR:Int, startC:Int, endR:Int, endC:Int, pieceId:String, callback:Void->Void, ?enPassantVictimRow:Null<Int>,
        ?enPassantVictimCol:Null<Int>, ?animated:Bool = true):Void;
    
    /**
     * Animate a castling move (king and rook move simultaneously)
     */
    function animateCastling(kingStartR:Int, kingStartC:Int, kingEndR:Int, kingEndC:Int, 
                            rookStartR:Int, rookStartC:Int, rookEndR:Int, rookEndC:Int, callback:Void->Void, ?animated:Bool = true):Void;
    
    /**
     * Update a single tile with a new piece
     */
    function updateTile(row:Int, col:Int, newId:String):Void;
    
    /**
     * Clear all pieces
     */
    function clear():Void;

    /**
     * Create a draggable bitmap of a piece
     */
    function createDragPiece(pieceId:String):openfl.display.Bitmap;
    
    /**
     * Hide the piece at the specified position
     */
    function hidePieceAt(row:Int, col:Int):Void;
    
    /**
     * Show the piece at the specified position
     */
    function showPieceAt(row:Int, col:Int):Void;

    /** Resize piece sprites to match new tile size; caller should call `render` after. */
    function setTileSize(size:Int):Void;

    /** Replace the piece at (row,col) with a spawn-in tween (e.g. history step back over a capture). */
    function replaySquareWithSpawn(row:Int, col:Int, pieceId:String):Void;
}