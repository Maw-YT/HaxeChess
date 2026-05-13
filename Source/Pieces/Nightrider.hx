package pieces;

import openfl.geom.Point;
import utils.MoveUtils;

/** Nightrider: repeated knight leaps along the same ray. */
class Nightrider extends BasePiece {
    public function new(color:String) {
        super("nightrider", color);
    }

    override public function getValidMoves(currentRow:Int, currentCol:Int, board:Array<Array<String>>):Array<Point> {
        return MoveUtils.getKnightRiderMoves(currentRow, currentCol, board, getColor());
    }
}
