package managers;

import openfl.geom.Point;
import interfaces.IPiece;
import pieces.PieceFactory;
import utils.BoardUtils;

class ValidationManager {
    
    // This flag prevents the King from checking Castling while 
    // we are already in the middle of a check-validation.
    public static var isValidating:Bool = false;

    static function isSquareAttackedByEnemy(defenderColor:String, row:Int, col:Int, board:Array<Array<String>>):Bool {
        if (board == null)
            return false;
        var oldValidating = isValidating;
        isValidating = true;
        for (r in 0...board.length) {
            var line = board[r];
            if (line == null)
                continue;
            for (c in 0...line.length) {
                var pId = line[c];
                if (pId == "" || BoardUtils.isPieceOfColor(pId, defenderColor))
                    continue;
                var enemy = PieceFactory.createPiece(pId);
                if (enemy == null)
                    continue;
                var captures = enemy.getCaptureMoves(r, c, board);
                for (mv in captures) {
                    if (Std.int(mv.y) == row && Std.int(mv.x) == col) {
                        isValidating = oldValidating;
                        return true;
                    }
                }
            }
        }
        isValidating = oldValidating;
        return false;
    }
    
    public static function isValidMove(piece:IPiece, start:Point, end:Point, board:Array<Array<String>>):Bool {
        if (piece == null || board == null)
            return false;
        var startX = Std.int(start.x);
        var startY = Std.int(start.y);
        var endX = Std.int(end.x);
        var endY = Std.int(end.y);
        if (BoardUtils.cellAt(board, startY, startX) == null || BoardUtils.cellAt(board, endY, endX) == null)
            return false;

        // Castling: only when this exact move is legal castling (not a normal king step onto c/g).
        var isCastling = false;
        var castlingSide:String = null;
        if (piece.getType() == "king" && endY == startY && CastlingManager.instance != null) {
            var endCell = BoardUtils.cellAt(board, endY, endX);
            if (endCell != null && endCell == "") {
                castlingSide = CastlingManager.instance.getCastlingSideIfMove(piece.getColor(), board, startX, startY, endX, endY);
                isCastling = castlingSide != null;
            }
        }
        
        // 1. Basic physics check (can the piece actually move there?)
        if (!isCastling) {
            // We set isValidating to true so King.getValidMoves skips castling here
            var oldValidating = isValidating;
            isValidating = true;
            
            var moves = piece.getValidMoves(startY, startX, board);
            var caps = piece.getCaptureMoves(startY, startX, board);
            var canPhysicsMove = utils.MoveUtils.hasMove(moves.concat(caps), end);

            isValidating = oldValidating;
            
            if (!canPhysicsMove) {
                return false;
            }
        }

        // 2. Simulation check (does this move put/leave our king in check?)
        var rookStartCol = -1;
        var rookEndCol = -1;
        
        if (isCastling && CastlingManager.instance != null) {
            var rookCols = CastlingManager.instance.getCastlingRookColumns(piece.getColor(), castlingSide, board, startX);
            rookStartCol = rookCols.startCol;
            rookEndCol = rookCols.endCol;
        }

        var sim = BoardUtils.copyBoard(board);
        if (isCastling) {
            if (rookStartCol < 0 || rookEndCol < 0)
                return false;
            var kingPiece = board[startY][startX];
            var rookPiece = board[startY][rookStartCol];
            sim[startY][startX] = "";
            sim[startY][rookStartCol] = "";
            sim[endY][endX] = kingPiece;
            sim[startY][rookEndCol] = rookPiece;
        } else {
            var moving = board[startY][startX];
            sim[endY][endX] = moving;
            sim[startY][startX] = "";
        }

        var inCheckAfterMove = isCastling
            ? isSquareAttackedByEnemy(piece.getColor(), endY, endX, sim)
            : isCheck(piece.getColor(), sim);

        return !inCheckAfterMove;
    }
    
    public static function isCheck(color:String, board:Array<Array<String>>):Bool {
        if (board == null)
            return false;
        var royalPositions = BoardUtils.findAllRoyalPieces(board, color);
        
        // CRITICAL FIX: If no royal pieces are not found (happens if board layout is wrong)
        // or during specific simulations), return false instead of crashing.
        if (royalPositions == null || royalPositions.length == 0) return false;

        var oldValidating = isValidating;
        isValidating = true;

        for (r in 0...board.length) {
            var row = board[r];
            if (row == null)
                continue;
            for (c in 0...row.length) {
                var pId = row[c];
                // Check if this is an enemy piece
                if (pId != "" && !BoardUtils.isPieceOfColor(pId, color)) {
                    var enemy = PieceFactory.createPiece(pId);
                    if (enemy == null) continue;
                    
                    var moves = enemy.getCaptureMoves(r, c, board);
                    for (m in moves) {
                        for (royalPos in royalPositions) {
                            if (m.x == royalPos.x && m.y == royalPos.y) {
                                isValidating = oldValidating;
                                return true;
                            }
                        }
                    }
                }
            }
        }
        
        isValidating = oldValidating;
        return false;
    }
    
    public static function getGameState(color:String, board:Array<Array<String>>):String {
        if (board == null)
            return "active";
        var hasLegalMove = false;
        
        for (r in 0...board.length) {
            var row = board[r];
            if (row == null)
                continue;
            for (c in 0...row.length) {
                var pId = row[c];
                if (pId != "" && BoardUtils.isPieceOfColor(pId, color)) {
                    var p = PieceFactory.createPiece(pId);
                    if (p == null)
                        continue;
                    var moves = p.getValidMoves(r, c, board).concat(p.getCaptureMoves(r, c, board));
                    for (m in moves) {
                        if (isValidMove(p, new Point(c, r), m, board)) {
                            hasLegalMove = true;
                            break;
                        }
                    }
                }
                if (hasLegalMove) break;
            }
            if (hasLegalMove) break;
        }

        var check = isCheck(color, board);
        if (!hasLegalMove) return check ? "checkmate" : "stalemate";
        return check ? "check" : "active";
    }
        
    /**
     * Find all royal pieces of the given color that are currently under attack
     */
    public static function getCheckedRoyals(color:String, board:Array<Array<String>>):Array<Point> {
        if (board == null)
            return [];
        var royalPositions = BoardUtils.findAllRoyalPieces(board, color);
        var checkedRoyals:Array<Point> = [];
        
        if (royalPositions == null || royalPositions.length == 0) return checkedRoyals;

        var oldValidating = isValidating;
        isValidating = true;

        // Check each enemy piece to see if it attacks any royal piece
        for (r in 0...board.length) {
            var row = board[r];
            if (row == null)
                continue;
            for (c in 0...row.length) {
                var pId = row[c];
                if (pId != "" && !BoardUtils.isPieceOfColor(pId, color)) {
                    var enemy = PieceFactory.createPiece(pId);
                    if (enemy == null) continue;
                    
                    var moves = enemy.getCaptureMoves(r, c, board);
                    for (m in moves) {
                        for (royalPos in royalPositions) {
                            // If this royal position is attacked and not already in the list
                            if (m.x == royalPos.x && m.y == royalPos.y) {
                                var alreadyAdded = false;
                                for (existing in checkedRoyals) {
                                    if (existing.x == royalPos.x && existing.y == royalPos.y) {
                                        alreadyAdded = true;
                                        break;
                                    }
                                }
                                if (!alreadyAdded) {
                                    checkedRoyals.push(royalPos);
                                }
                            }
                        }
                    }
                }
            }
        }
        
        isValidating = oldValidating;
        return checkedRoyals;
    }
}