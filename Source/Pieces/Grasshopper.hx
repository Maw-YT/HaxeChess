package pieces;

import openfl.geom.Point;
import utils.BoardUtils;

/**
 * Grasshopper: moves on queen lines; must jump over exactly one piece (any color),
 * then lands on the first square immediately beyond that hurdle (captures only on landing).
 */
class Grasshopper extends BasePiece {
    public function new(color:String) {
        super("grasshopper", color);
    }

    override public function getValidMoves(currentRow:Int, currentCol:Int, board:Array<Array<String>>):Array<Point> {
        var dirs = [
            {r: 1, c: 0}, {r: -1, c: 0}, {r: 0, c: 1}, {r: 0, c: -1},
            {r: 1, c: 1}, {r: 1, c: -1}, {r: -1, c: 1}, {r: -1, c: -1}
        ];
        var moves:Array<Point> = [];
        var myColor = getColor();
        for (dir in dirs) {
            var r = currentRow + dir.r;
            var c = currentCol + dir.c;
            while (BoardUtils.isValidPosition(r, c)) {
                if (!BoardUtils.isPositionEmpty(board, r, c)) {
                    var lr = r + dir.r;
                    var lc = c + dir.c;
                    if (BoardUtils.isValidPosition(lr, lc)) {
                        if (BoardUtils.isPositionEmpty(board, lr, lc) || (BoardUtils.isEnemyPiece(board, lr, lc, myColor) && !BoardUtils.isSquareProtectedByShield(lr, lc, board)))
                            moves.push(new Point(lc, lr));
                    }
                    break;
                }
                r += dir.r;
                c += dir.c;
            }
        }
        return moves;
    }
}
