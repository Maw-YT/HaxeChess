package pieces;

import openfl.geom.Point;
import config.GameConfig;
import utils.BoardUtils;
import utils.MoveUtils;
import interfaces.IPiece;

/**
 * Base implementation of IPiece
 * Provides common functionality for all piece types
 */
class BasePiece implements IPiece {
    private var _type:String;
    private var _color:String;
    private var _isRoyal:Bool = false;
    private var _value:Int = 0;
    
    public function new(type:String, color:String) {
        this._type = type;
        this._color = color;
        
        // Set default value from config
        if (GameConfig.PIECE_VALUES.exists(type)) {
            this._value = GameConfig.PIECE_VALUES.get(type);
        }
    }
    
    public function getType():String {
        return _type;
    }
    
    public function getColor():String {
        return _color;
    }
    
    public function getId():String {
        return _type + "-" + _color;
    }
    
    public function isRoyal():Bool {
        return _isRoyal;
    }
    
    public function getValue():Int {
        return _value;
    }
    
    /**
     * Set this piece as royal (king)
     */
    public function setRoyal(isRoyal:Bool):Void {
        this._isRoyal = isRoyal;
    }
    
    /**
     * Set a custom value for this piece
     */
    public function setValue(value:Int):Void {
        this._value = value;
    }
    
    // Standard movement (usually includes captures)
    public function getValidMoves(currentRow:Int, currentCol:Int, board:Array<Array<String>>):Array<Point> {
        return []; 
    }

    // Specifically for pieces that capture differently (like Pawns)
    public function getCaptureMoves(currentRow:Int, currentCol:Int, board:Array<Array<String>>):Array<Point> {
        return getValidMoves(currentRow, currentCol, board);
    }
    
    /**
     * Helper method for sliding pieces (rook, bishop, queen, nuke)
     */
    public function getSlidingMoves(startRow:Int, startCol:Int, dirs:Array<{r:Int, c:Int}>, board:Array<Array<String>>):Array<Point> {
        return MoveUtils.getSlidingMoves(startRow, startCol, dirs, board, _color);
    }
    
    /**
     * Helper method for step pieces (king, knight)
     */
    public function getStepMoves(startRow:Int, startCol:Int, offsets:Array<{r:Int, c:Int}>, board:Array<Array<String>>):Array<Point> {
        return MoveUtils.getStepMoves(startRow, startCol, offsets, board, _color);
    }
}