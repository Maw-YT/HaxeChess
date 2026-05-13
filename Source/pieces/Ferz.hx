package pieces;

import openfl.geom.Point;

/**
 * Ferz: Moves one square in any diagonal direction
 * Similar to a very weak bishop
 */
class Ferz extends BasePiece {
    public function new(color:String) {
        super("ferz", color);
    }
    
    override public function getValidMoves(currentRow:Int, currentCol:Int, board:Array<Array<String>>):Array<Point> {
        var offsets = [
            {r: 1, c: 1}, {r: 1, c: -1}, {r: -1, c: 1}, {r: -1, c: -1}
        ];
        return getStepMoves(currentRow, currentCol, offsets, board);
    }
}
