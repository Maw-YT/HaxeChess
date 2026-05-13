package pieces;

import openfl.geom.Point;

/**
 * Shield: one-square step movement with a defensive aura.
 * The Shield cannot capture or be captured when the target is inside a shield aura,
 * except when the target itself is another shield.
 */
class Shield extends BasePiece {
    public function new(color:String) {
        super("shield", color);
    }

    override public function getValidMoves(currentRow:Int, currentCol:Int, board:Array<Array<String>>):Array<Point> {
        var offsets = [];
        for (dr in -1...2) {
            for (dc in -1...2) {
                if (dr == 0 && dc == 0) continue;
                offsets.push({r: dr, c: dc});
            }
        }
        return getStepMoves(currentRow, currentCol, offsets, board);
    }

    override public function getCaptureMoves(currentRow:Int, currentCol:Int, board:Array<Array<String>>):Array<Point> {
        return getValidMoves(currentRow, currentCol, board);
    }
}
