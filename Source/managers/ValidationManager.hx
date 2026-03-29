package managers;

import openfl.geom.Point;
import interfaces.IPiece;
import pieces.PieceFactory;
import utils.BoardUtils;

class ValidationManager {
    
    // This flag prevents the King from checking Castling while 
    // we are already in the middle of a check-validation.
    public static var isValidating:Bool = false;
    
    public static function isValidMove(piece:IPiece, start:Point, end:Point, board:Array<Array<String>>):Bool {
        var startX = Std.int(start.x);
        var startY = Std.int(start.y);
        var endX = Std.int(end.x);
        var endY = Std.int(end.y);
        
        // Special case: Castling (King moves 2 spaces horizontally)
        // This is always physically valid if it's a King - the CastlingManager will validate legality
        var isCastling = false;
        if (piece.getType() == "king" && Math.abs(endX - startX) == 2 && endY == startY) {
            isCastling = true;
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
        } else {
            // Castling: verify legality with CastlingManager
            var side = (endX > startX) ? "kingside" : "queenside";
            if (!CastlingManager.instance.canCastle(piece.getColor(), side, board)) {
                return false;
            }
        }

        // 2. Simulation check (does this move put/leave our king in check?)
        // Store original values for restoration
        var originalTarget = board[endY][endX];
        var originalStart = board[startY][startX];
        
        var rookStartCol = -1;
        var rookEndCol = -1;
        
        if (isCastling) {
            // Determine kingside or queenside
            if (endX > startX) {
                // Kingside castling: rook moves from column 7 to column 5
                rookStartCol = 7;
                rookEndCol = 5;
            } else {
                // Queenside castling: rook moves from column 0 to column 3
                rookStartCol = 0;
                rookEndCol = 3;
            }
        }
        
        // Simulate the move(s)
        board[endY][endX] = originalStart;
        board[startY][startX] = "";
        
        var rookOriginalTarget = "";
        var rookOriginalStart = "";
        if (isCastling) {
            // Also move the rook
            rookOriginalStart = board[startY][rookStartCol];
            rookOriginalTarget = board[startY][rookEndCol];
            board[startY][rookEndCol] = rookOriginalStart;
            board[startY][rookStartCol] = "";
        }

        var inCheckAfterMove = isCheck(piece.getColor(), board);

        // Undo all moves
        board[startY][startX] = originalStart;
        board[endY][endX] = originalTarget;
        
        if (isCastling) {
            board[startY][rookStartCol] = rookOriginalStart;
            board[startY][rookEndCol] = rookOriginalTarget;
        }

        return !inCheckAfterMove;
    }
    
    public static function isCheck(color:String, board:Array<Array<String>>):Bool {
        var kingPos = BoardUtils.findRoyalPiece(board, color);
        
        // CRITICAL FIX: If king is not found (happens if board layout is wrong 
        // or during specific simulations), return false instead of crashing.
        if (kingPos == null) return false;

        var oldValidating = isValidating;
        isValidating = true;

        for (r in 0...8) {
            for (c in 0...8) {
                var pId = board[r][c];
                // Check if this is an enemy piece
                if (pId != "" && !BoardUtils.isPieceOfColor(pId, color)) {
                    var enemy = PieceFactory.createPiece(pId);
                    if (enemy == null) continue;
                    
                    var moves = enemy.getCaptureMoves(r, c, board);
                    for (m in moves) {
                        if (m.x == kingPos.x && m.y == kingPos.y) {
                            isValidating = oldValidating;
                            return true;
                        }
                    }
                }
            }
        }
        
        isValidating = oldValidating;
        return false;
    }
    
    public static function getGameState(color:String, board:Array<Array<String>>):String {
        var hasLegalMove = false;
        
        for (r in 0...8) {
            for (c in 0...8) {
                var pId = board[r][c];
                if (pId != "" && BoardUtils.isPieceOfColor(pId, color)) {
                    var p = PieceFactory.createPiece(pId);
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
}