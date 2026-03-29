package pieces;

import openfl.geom.Point;
import managers.BoardManager;

/**
 * Pawn: Forward movement, diagonal capture
 */
class Pawn extends BasePiece {
    public function new(color:String) {
        super("pawn", color);
    }
    
    override public function getValidMoves(currentRow:Int, currentCol:Int, board:Array<Array<String>>):Array<Point> {
        var moves:Array<Point> = [];
        var forward = (getColor() == "w") ? -1 : 1;
        var startRow = (getColor() == "w") ? 6 : 1;
        var nextR = currentRow + forward;
        
        // Move forward 1
        if (utils.BoardUtils.isValidPosition(nextR, currentCol) && utils.BoardUtils.isPositionEmpty(board, nextR, currentCol)) {
            moves.push(new Point(currentCol, nextR));
            
            // Initial double move
            var doubleR = currentRow + (forward * 2);
            if (currentRow == startRow && utils.BoardUtils.isPositionEmpty(board, doubleR, currentCol)) {
                moves.push(new Point(currentCol, doubleR));
            }
        }
        
        return moves;
    }
    
    override public function getCaptureMoves(currentRow:Int, currentCol:Int, board:Array<Array<String>>):Array<Point> {
        var captures:Array<Point> = [];
        var forward = (getColor() == "w") ? -1 : 1;
        var nextR = currentRow + forward;
        var diagCols = [currentCol - 1, currentCol + 1];
        
        // Normal diagonal captures
        if (utils.BoardUtils.isValidPosition(nextR, 0)) {
            for (nc in diagCols) {
                if (utils.BoardUtils.isValidPosition(nextR, nc)) {
                    if (utils.BoardUtils.isEnemyPiece(board, nextR, nc, getColor())) {
                        captures.push(new Point(nc, nextR));
                    }
                }
            }
        }
        
        // En Passant capture
        // Only available for pawns on the correct rank and when enemy just moved 2 squares
        var onEnPassantRank = (getColor() == "w" && currentRow == 3) || (getColor() == "b" && currentRow == 4);
        if (onEnPassantRank) {
            var boardManager = managers.BoardManager.instance;
            if (boardManager != null) {
                var lastMoveStart = boardManager.getLastMoveStart();
                var lastMoveEnd = boardManager.getLastMoveEnd();
                var lastMovedPiece = boardManager.getLastMovedPiece();
                
                if (lastMoveStart != null && lastMoveEnd != null && lastMovedPiece != "") {
                    var lastParsed = utils.BoardUtils.parsePieceId(lastMovedPiece);
                    // Check if last move was enemy pawn moving 2 squares
                    if (lastParsed.type == "pawn" && lastParsed.color != getColor()) {
                        var moveDistance = Math.abs(Std.int(lastMoveEnd.y) - Std.int(lastMoveStart.y));
                        if (moveDistance == 2) {
                            // En passant is available if the enemy pawn is adjacent to us
                            var enPassantCol = Std.int(lastMoveEnd.x);
                            if (Math.abs(enPassantCol - currentCol) == 1) {
                                // Can capture on the diagonal forward to that column
                                captures.push(new Point(enPassantCol, nextR));
                            }
                        }
                    }
                }
            }
        }
        
        return captures;
    }
}