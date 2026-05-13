package controllers;

import openfl.geom.Point;
import interfaces.IGameController;
import managers.BoardManager;
import managers.ValidationManager;
import pieces.PieceFactory;
import interfaces.IPiece;
import managers.CastlingManager;
import ui.PromotionMenu;
import managers.SoundManager;
import utils.BoardUtils;
import utils.DrawRules;
import utils.BoardToFEN;
import utils.ChessNotation;
import config.SettingsConfig;
import config.BoardLayout;

/**
 * Main game controller implementing IGameController
 * Coordinates between board state, validation, and game logic
 */
class GameController implements IGameController {
    private var boardManager:BoardManager;
    private var startingLayout:Array<Array<String>>;
    private var gameState:String;
    private var promotionMenu:PromotionMenu;
    private var onPromotionCompleted:Void->Void;
    private var positionKeyCounts:Map<String, Int>;

    /** Half-moves from start shown on the board; equals history length when following live play. */
    private var historyViewPly:Int = 0;
    
    public function new() {
        // Initialize piece factory with standard pieces
        PieceFactory.init();
        new CastlingManager();
        SoundManager.getInstance(); // Initialize sound manager
        
        var layout = BoardLayout.getLayoutById(SettingsConfig.boardLayoutId);
        this.startingLayout = BoardUtils.copyBoard(layout);
        this.boardManager = new BoardManager(layout);
        this.gameState = "active";
        this.positionKeyCounts = new Map();
        recordStartingPositionForRepetition();
    }

    function buildPositionKey():String {
        var board = getBoardData();
        var castle = CastlingManager.instance != null ? CastlingManager.instance.getCastlingRightsFEN(board) : "-";
        return DrawRules.repetitionPositionKey(board, getCurrentTurn(), castle, boardManager.getEpTargetFEN());
    }

    function recordStartingPositionForRepetition():Void {
        var k = buildPositionKey();
        positionKeyCounts.set(k, 1);
    }

    function notePositionAfterHalfMove():Void {
        var key = buildPositionKey();
        var c = positionKeyCounts.get(key);
        if (c == null)
            c = 0;
        c++;
        positionKeyCounts.set(key, c);

        var board = getBoardData();

        if (c >= 3) {
            gameState = "draw_repetition";
            syncHistoryViewPlyToLive();
            return;
        }

        if (applyNoRoyalMaterialWin(board)) {
            syncHistoryViewPlyToLive();
            return;
        }
        resolveNonRoyalState();
        syncHistoryViewPlyToLive();
    }

    function syncHistoryViewPlyToLive():Void {
        historyViewPly = boardManager.getMoveHistory().length;
    }

    /**
     * When there are no royal pieces (king / royal pawn) left on the board for either side,
     * win by capturing all enemy pieces — last side with material wins.
     */
    function applyNoRoyalMaterialWin(board:Array<Array<String>>):Bool {
        var wr = BoardUtils.findAllRoyalPieces(board, "w");
        var br = BoardUtils.findAllRoyalPieces(board, "b");
        if (wr.length > 0 || br.length > 0)
            return false;
        var wp = BoardUtils.countPiecesOfColor(board, "w");
        var bp = BoardUtils.countPiecesOfColor(board, "b");
        if (wp == 0 && bp == 0) {
            gameState = "draw_no_royals";
            return true;
        }
        if (wp == 0) {
            gameState = "win_black";
            return true;
        }
        if (bp == 0) {
            gameState = "win_white";
            return true;
        }
        return false;
    }

    function resolveNonRoyalState():Void {
        var turn = getCurrentTurn();
        var board = getBoardData();
        gameState = ValidationManager.getGameState(turn, board);
        if (gameState != "checkmate" && gameState != "stalemate") {
            if (DrawRules.isInsufficientMaterial(board))
                gameState = "draw_material";
        }
    }
    
    public function getBoardData():Array<Array<String>> {
        return boardManager.getBoardData();
    }
    
    public function getCurrentTurn():String {
        return boardManager.getCurrentTurn();
    }
    
    public function getSelectedTile():Point {
        return boardManager.getSelectedTile();
    }
    
    public function handleSelect(col:Int, row:Int):Bool {
        if (SettingsConfig.allowIllegalMoves)
            return boardManager.handleSelectAnyPiece(col, row);
        return boardManager.handleSelect(col, row);
    }
    
    public function attemptMove(col:Int, row:Int):Bool {
        var startPos = boardManager.getSelectedTile();
        if (startPos == null) return false;
        
        var endPos = new Point(col, row);
        var pieceStr = boardManager.getPieceAt(Std.int(startPos.x), Std.int(startPos.y));
        var piece:IPiece = PieceFactory.createPiece(pieceStr);
        
        // Null check to prevent crashes if piece creation fails
        if (piece == null) {
            boardManager.setSelectedTile(null);
            return false;
        }
        
        var board = boardManager.getBoardData();
        if (ValidationManager.isValidMove(piece, startPos, endPos, board)) {
            // Check if this move results in promotion
            if (boardManager.checkNeedsPromotion(startPos, endPos)) {
                // Store the pending move and show promotion menu
                boardManager.setPendingPromotion(startPos, endPos);
                boardManager.setSelectedTile(null);
                
                if (promotionMenu == null) {
                    promotionMenu = new PromotionMenu();
                }
                promotionMenu.show(onPromotionSelected, getCurrentTurn());
                
                return true;
            }
            
            // Not a promotion - complete the move normally
            boardManager.executeMove(startPos, endPos);
            boardManager.recordHalfMove(Std.int(startPos.x), Std.int(startPos.y), Std.int(endPos.x), Std.int(endPos.y), "");

            // Clear the selected tile after move
            boardManager.setSelectedTile(null);
            
            // Switch turn to the next player
            boardManager.switchTurn();
            notePositionAfterHalfMove();
            
            return true;
        }

        if (SettingsConfig.allowIllegalMoves) {
            if (boardManager.checkNeedsPromotion(startPos, endPos)) {
                boardManager.setPendingPromotion(startPos, endPos);
                boardManager.setSelectedTile(null);
                if (promotionMenu == null)
                    promotionMenu = new PromotionMenu();
                promotionMenu.show(onPromotionSelected, getCurrentTurn());
                return true;
            }
            boardManager.executeRelocateOnly(startPos, endPos);
            boardManager.recordHalfMove(Std.int(startPos.x), Std.int(startPos.y), Std.int(endPos.x), Std.int(endPos.y), "");
            boardManager.setSelectedTile(null);
            boardManager.switchTurn();
            notePositionAfterHalfMove();
            return true;
        }
        
        boardManager.setSelectedTile(null);
        return false;
    }
    
    public function getLegalMovesForSelection():Array<Point> {
        var selected = boardManager.getSelectedTile();
        if (selected == null) return [];
        
        var moves:Array<Point> = [];
        var pieceStr = boardManager.getPieceAt(Std.int(selected.x), Std.int(selected.y));
        var piece:IPiece = PieceFactory.createPiece(pieceStr);
        
        // Check every tile to see if it's a legal move
        var bd = boardManager.getBoardData();
        for (r in 0...bd.length) {
            var row = bd[r];
            for (c in 0...row.length) {
                var target = new Point(c, r);
                if (ValidationManager.isValidMove(piece, selected, target, bd)) {
                    moves.push(target);
                }
            }
        }
        
        return moves;
    }

    public function getCaptureMovesForSelection():Array<Point> {
        var selected = boardManager.getSelectedTile();
        if (selected == null) return [];
        
        var moves:Array<Point> = [];
        var pieceStr = boardManager.getPieceAt(Std.int(selected.x), Std.int(selected.y));
        var piece:IPiece = PieceFactory.createPiece(pieceStr);
        
        if (piece == null) return [];
        
        var myColor = piece.getColor();
        var board = boardManager.getBoardData();
        
        // Get capture moves specifically
        var captureMoves = piece.getCaptureMoves(Std.int(selected.y), Std.int(selected.x), board);
        
        // Filter to only valid moves that have an enemy piece
        for (target in captureMoves) {
            var targetRow = Std.int(target.y);
            var targetCol = Std.int(target.x);
            var targetPiece = board[targetRow][targetCol];
            
            // Only include if there's an enemy piece to capture
            if (targetPiece != "" && !BoardUtils.isPieceOfColor(targetPiece, myColor)) {
                if (ValidationManager.isValidMove(piece, selected, target, board)) {
                    moves.push(target);
                }
            }
        }
        
        return moves;
    }
    
    public function getGameState():String {
        return gameState;
    }
    
    public function getCheckedRoyals():Array<Point> {
        if (gameState == "draw_repetition" || gameState == "draw_material" || gameState == "draw_no_royals")
            return [];
        if (gameState == "win_white" || gameState == "win_black")
            return [];
        if (gameState == "check" || gameState == "checkmate") {
            var currentColor = getCurrentTurn();
            return ValidationManager.getCheckedRoyals(currentColor, getBoardData());
        }
        return [];
    }

    /**
     * Called when player selects a promotion piece
     */
    private function onPromotionSelected(pieceType:String):Void {
        boardManager.completePendingPromotion(pieceType);
        
        // Now complete the turn
        boardManager.switchTurn();
        notePositionAfterHalfMove();
        
        if (gameState == "checkmate") {
            trace("Game Over: Checkmate!");
        } else if (gameState == "stalemate") {
            trace("Game Over: Stalemate!");
        } else if (gameState == "draw_repetition") {
            trace("Game Over: Draw by repetition");
        } else if (gameState == "draw_material") {
            trace("Game Over: Draw — insufficient material");
        } else if (gameState == "win_white") {
            trace("Game Over: White wins (all black pieces captured, no royals on board)");
        } else if (gameState == "win_black") {
            trace("Game Over: Black wins (all white pieces captured, no royals on board)");
        } else if (gameState == "draw_no_royals") {
            trace("Game Over: Draw — board empty (no royals mode)");
        } else if (gameState == "check") {
            trace("Check!");
        }
        
        // Trigger the completion callback so Main can re-render
        if (onPromotionCompleted != null) {
            onPromotionCompleted();
        }
    }
    
    /**
     * Set the callback for when promotion is completed
     */
    public function setOnPromotionCompleted(callback:Void->Void):Void {
        onPromotionCompleted = callback;
    }
    
    /**
     * Get the promotion menu for adding to the stage
     */
    public function getPromotionMenu():PromotionMenu {
        if (promotionMenu == null) {
            promotionMenu = new PromotionMenu();
        }
        return promotionMenu;
    }
    
    /**
     * Check if there's a pending promotion
     */
    public function isPendingPromotion():Bool {
        return boardManager.isPendingPromotion();
    }
        
    /**
     * Check if a position has a piece (for detecting captures)
     */
    public function hasPieceAt(col:Int, row:Int):Bool {
        var piece = boardManager.getPieceAt(col, row);
        return piece != null && piece != "";
    }
        
    /**
     * Check if the last move was a castling move
     */
    /** Pass the board as it is before the move (e.g. current board when deciding the pending move). */
    public function isCastlingMove(startPos:Point, endPos:Point):Bool {
        var board = boardManager.getBoardData();
        var pieceStr = boardManager.getPieceAt(Std.int(startPos.x), Std.int(startPos.y));
        if (pieceStr.indexOf("king") != 0) return false;
        var p = BoardUtils.parsePieceId(pieceStr);
        return CastlingManager.instance != null
            && CastlingManager.instance.getCastlingSideIfMove(
                p.color,
                board,
                Std.int(startPos.x),
                Std.int(startPos.y),
                Std.int(endPos.x),
                Std.int(endPos.y)
            ) != null;
    }

        
    /**
     * Execute a move from UCI notation (for engine moves)
     */
    public function executeUCIMove(uciMove:String):Bool {
        var moveData = utils.ChessNotation.parseUCI(uciMove);
        if (moveData == null) return false;
        
        return executeMoveFromCoords(moveData.fromCol, moveData.fromRow, 
                                      moveData.toCol, moveData.toRow, 
                                      moveData.promotion);
    }
    
    /**
     * Execute a move from coordinates with optional promotion
     */
    public function executeMoveFromCoords(fromCol:Int, fromRow:Int, toCol:Int, toRow:Int, ?promotion:String = ""):Bool {
        var startPos = new Point(fromCol, fromRow);
        var endPos = new Point(toCol, toRow);
        var pieceStr = boardManager.getPieceAt(fromCol, fromRow);
        var piece:IPiece = PieceFactory.createPiece(pieceStr);
        
        if (piece == null) return false;

        var board = boardManager.getBoardData();
        var legal = ValidationManager.isValidMove(piece, startPos, endPos, board);
        if (!legal && !SettingsConfig.allowIllegalMoves)
            return false;

        if (legal) {
            if (boardManager.checkNeedsPromotion(startPos, endPos)) {
                // Same path as human promotion menu: pending + complete (do not executeMove first — start
                // square must still hold the pawn or completePendingPromotion no-ops).
                boardManager.setPendingPromotion(startPos, endPos);
                var promoType = ChessNotation.uciToPromotion(promotion);
                if (promoType == "")
                    promoType = "queen";
                boardManager.completePendingPromotion(promoType);
            } else {
                boardManager.executeMove(startPos, endPos);
                boardManager.recordHalfMove(fromCol, fromRow, toCol, toRow, "");
            }
        } else {
            if (boardManager.checkNeedsPromotion(startPos, endPos)) {
                boardManager.executeRelocateOnly(startPos, endPos);
                var parsed = BoardUtils.parsePieceId(pieceStr);
                var promoType = ChessNotation.uciToPromotion(promotion);
                if (promoType == "")
                    promoType = "queen";
                boardManager.setPieceAt(toCol, toRow, promoType + "-" + parsed.color);
                boardManager.recordHalfMove(fromCol, fromRow, toCol, toRow, ChessNotation.promotionToUCI(promoType));
            } else {
                boardManager.executeRelocateOnly(startPos, endPos);
                boardManager.recordHalfMove(fromCol, fromRow, toCol, toRow, "");
            }
        }

        boardManager.setSelectedTile(null);
        boardManager.switchTurn();
        notePositionAfterHalfMove();

        return true;
    }

    public function getMoveHistory():Array<String> {
        return boardManager.getMoveHistory();
    }

    public function setPieceAt(col:Int, row:Int, pieceId:String):Void {
        boardManager.setPieceAt(col, row, pieceId);
    }

    public function isBrowsingHistory():Bool {
        return historyViewPly < boardManager.getMoveHistory().length;
    }

    public function getHistoryViewPly():Int {
        return historyViewPly;
    }

    public function getLastMoveHighlightFrom():Null<Point> {
        var p = computeLastMoveHighlight();
        return p == null ? null : p.from;
    }

    public function getLastMoveHighlightTo():Null<Point> {
        var p = computeLastMoveHighlight();
        return p == null ? null : p.to;
    }

    function computeLastMoveHighlight():Null<{from:Point, to:Point}> {
        var full = boardManager.getMoveHistory();
        if (full.length == 0 || historyViewPly <= 0)
            return null;
        var idx = historyViewPly - 1;
        if (idx < 0 || idx >= full.length)
            return null;
        var m = ChessNotation.parseUCI(full[idx]);
        if (m == null)
            return null;
        return {from: new Point(m.fromCol, m.fromRow), to: new Point(m.toCol, m.toRow)};
    }

    public function stepHistoryView(delta:Int):Void {
        var len = boardManager.getMoveHistory().length;
        if (len == 0)
            return;
        var next = historyViewPly + delta;
        if (next < 0)
            next = 0;
        if (next > len)
            next = len;
        historyViewPly = next;
        replayBoardToHistoryViewPly();
    }

    function replayBoardToHistoryViewPly():Void {
        var full = boardManager.getMoveHistory().copy();
        if (CastlingManager.instance != null)
            CastlingManager.instance.resetAll();
        boardManager.resetToLayout(startingLayout, true);
        positionKeyCounts = new Map();
        recordStartingPositionForRepetition();
        gameState = "active";
        if (!applyNoRoyalMaterialWin(getBoardData()))
            resolveNonRoyalState();
        for (i in 0...historyViewPly) {
            if (!executeUciReplayOnly(full[i]))
                trace("History replay failed at " + full[i]);
        }
        boardManager.setMoveHistory(full);
        boardManager.setSelectedTile(null);
    }

    function executeUciReplayOnly(uci:String):Bool {
        var moveData = ChessNotation.parseUCI(uci);
        if (moveData == null)
            return false;
        return executeMoveFromCoords(moveData.fromCol, moveData.fromRow, moveData.toCol, moveData.toRow, moveData.promotion);
    }
    
    /**
     * Get the board's FEN string
     */
    public function getFEN():String {
        var board = getBoardData();
        var castle = CastlingManager.instance != null ? CastlingManager.instance.getCastlingRightsFEN(board) : "-";
        return BoardToFEN.toFEN(board, getCurrentTurn(), castle, boardManager.getEpTargetFEN());
    }

    public function getEngineFEN():String {
        var board = getBoardData();
        var castle = CastlingManager.instance != null ? CastlingManager.instance.getCastlingRightsFEN(board) : "-";
        var placement = BoardToFEN.getEnginePiecePlacement(board);
        return placement + " " + getCurrentTurn() + " " + (castle != "" ? castle : "-") + " " + boardManager.getEpTargetFEN() + " 0 1";
    }

    public function getEngineStartFEN():String {
        var castle = CastlingManager.instance != null ? CastlingManager.instance.getInitialCastlingRightsFEN(startingLayout) : "-";
        var placement = BoardToFEN.getEnginePiecePlacement(startingLayout);
        return placement + " w " + (castle != "" ? castle : "-") + " - 0 1";
    }

    public function applySavedBoardLayout():Void {
        startingLayout = BoardUtils.copyBoard(BoardLayout.getLayoutById(SettingsConfig.boardLayoutId));
        resetBoardToClassic();
    }

    /** Standard starting position, white to move; clears history and repetition. */
    public function resetBoardToClassic():Void {
        if (promotionMenu != null)
            promotionMenu.hide();
        if (SettingsConfig.boardLayoutId == "chess960")
            startingLayout = BoardUtils.copyBoard(BoardLayout.getLayoutById("chess960"));
        if (CastlingManager.instance != null)
            CastlingManager.instance.resetAll();
        boardManager.resetToLayout(startingLayout, true);
        gameState = "active";
        positionKeyCounts = new Map();
        recordStartingPositionForRepetition();
        if (!applyNoRoyalMaterialWin(getBoardData()))
            resolveNonRoyalState();
        historyViewPly = 0;
    }
}