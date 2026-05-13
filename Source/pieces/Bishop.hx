package pieces;

import openfl.geom.Point;

/**
 * Bishop: Diagonal sliding piece
 */
class Bishop extends BasePiece {
    public function new(color:String) {
        super("bishop", color);
    }
    
    override public function getValidMoves(currentRow:Int, currentCol:Int, board:Array<Array<String>>):Array<Point> {
        var dirs = [
            {r: 1, c: 1}, {r: 1, c: -1}, 
            {r: -1, c: 1}, {r: -1, c: -1}
        ];
        return getSlidingMoves(currentRow, currentCol, dirs, board);
    }
}