package pieces;

import openfl.geom.Point;
import utils.MoveUtils;

/**
 * Centaur: combines king steps (no castling) and knight leaps. Not royal.
 */
class Centaur extends BasePiece {
    public function new(color:String) {
        super("centaur", color);
    }

    override public function getValidMoves(currentRow:Int, currentCol:Int, board:Array<Array<String>>):Array<Point> {
        var knightOff = [
            {r: 2, c: 1}, {r: 2, c: -1}, {r: -2, c: 1}, {r: -2, c: -1},
            {r: 1, c: 2}, {r: 1, c: -2}, {r: -1, c: 2}, {r: -1, c: -2}
        ];
        var kingOff:Array<{r:Int, c:Int}> = [];
        for (dr in -1...2) {
            for (dc in -1...2) {
                if (dr == 0 && dc == 0)
                    continue;
                kingOff.push({r: dr, c: dc});
            }
        }
        return MoveUtils.mergeUniquePoints(
            getStepMoves(currentRow, currentCol, knightOff, board),
            getStepMoves(currentRow, currentCol, kingOff, board)
        );
    }
}
