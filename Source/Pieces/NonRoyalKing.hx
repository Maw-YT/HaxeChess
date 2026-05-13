package pieces;

import openfl.geom.Point;

/**
 * Moves like a king (one step in any direction) but is not royal:
 * no check/checkmate role, no castling.
 */
class NonRoyalKing extends BasePiece {
    public function new(color:String) {
        super("nonroyalking", color);
    }

    override public function getValidMoves(currentRow:Int, currentCol:Int, board:Array<Array<String>>):Array<Point> {
        var offsets:Array<{r:Int, c:Int}> = [];
        for (dr in -1...2) {
            for (dc in -1...2) {
                if (dr == 0 && dc == 0)
                    continue;
                offsets.push({r: dr, c: dc});
            }
        }
        return getStepMoves(currentRow, currentCol, offsets, board);
    }
}
