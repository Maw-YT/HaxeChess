package pieces;

import openfl.geom.Point;

/**
 * Wazir: Moves one square in any orthogonal direction (up, down, left, right)
 * Similar to a very weak rook
 */
class Wazir extends BasePiece {
    public function new(color:String) {
        super("wazir", color);
    }
    
    override public function getValidMoves(currentRow:Int, currentCol:Int, board:Array<Array<String>>):Array<Point> {
        var offsets = [
            {r: 1, c: 0}, {r: -1, c: 0}, {r: 0, c: 1}, {r: 0, c: -1}
        ];
        return getStepMoves(currentRow, currentCol, offsets, board);
    }
}
