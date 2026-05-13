package utils;

import openfl.display.Sprite;
import openfl.display.Stage;
import openfl.display.Bitmap;
import openfl.media.SoundChannel;
import openfl.events.MouseEvent;
import openfl.events.Event;
import openfl.geom.Point;
import interfaces.IGameController;
import interfaces.IBoardRenderer;
import interfaces.IPieceRenderer;
import ui.BoardViewPort;
import config.GameConfig;
import config.SettingsConfig;
import managers.SoundManager;
import managers.ValidationManager;
import managers.CastlingManager;
import pieces.PieceFactory;
import utils.BoardUtils;
import utils.PieceCursor;

/**
 * Handles all mouse interactions for the chess game
 * Separates input handling logic from the main class
 */
class MouseHandler {
    private var stage:Stage;
    private var controller:IGameController;
    private var boardRenderer:IBoardRenderer;
    private var pieceRenderer:IPieceRenderer;
    /** Sprite whose local space matches the board grid (may be zoomed/panned). */
    private var boardContainer:Sprite;
    /** Input clip that defines the visible board viewport. */
    private var boardViewPort:BoardViewPort;
    private var tileSize:Int;
    
    private var isPieceDragging:Bool = false;
    private var dragPiece:Bitmap;
    private var dragStartTile:Point;
    private var dragStartStageX:Float = 0;
    private var dragStartStageY:Float = 0;
    
    private var isAnimating:Bool = false;
    private var enabled:Bool = true;

    /** When false, piece select / moves are ignored (engine's turn or engine thinking). */
    private var humanMayMove:Void->Bool;
    /** Left click on a board square — e.g. clear arrows; runs even when humanMayMove is false. */
    private var onBoardLeftTap:Int->Int->Void;
    
    // Callbacks
    private var onMoveCompleteCallback:Void->Void;
    private var onSelectionChangeCallback:Void->Void;
    private var onEngineTurnCallback:Void->Void;
    
    public function new(stage:Stage, controller:IGameController, boardRenderer:IBoardRenderer, 
                        pieceRenderer:IPieceRenderer, boardContainer:Sprite, boardViewPort:BoardViewPort, tileSize:Int) {
        this.stage = stage;
        this.controller = controller;
        this.boardRenderer = boardRenderer;
        this.pieceRenderer = pieceRenderer;
        this.boardContainer = boardContainer;
        this.boardViewPort = boardViewPort;
        this.tileSize = tileSize;
        
        setupEventListeners();
    }
    
    private function setupEventListeners():Void {
        stage.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
        stage.addEventListener(MouseEvent.MOUSE_MOVE, onMouseMove);
        stage.addEventListener(MouseEvent.MOUSE_UP, onMouseUp);
    }
    
    /**
     * Remove all event listeners (call when disposing)
     */
    public function dispose():Void {
        PieceCursor.setAuto();
        stage.removeEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
        stage.removeEventListener(MouseEvent.MOUSE_MOVE, onMouseMove);
        stage.removeEventListener(MouseEvent.MOUSE_UP, onMouseUp);
    }
    
    /**
     * Enable or disable mouse handling
     */
    public function setEnabled(enabled:Bool):Void {
        this.enabled = enabled;
        if (!enabled)
            PieceCursor.setAuto();
    }
    
    /**
     * Set whether an animation is in progress
     */
    public function setAnimating(animating:Bool):Void {
        this.isAnimating = animating;
    }

    public function getIsAnimating():Bool {
        return isAnimating;
    }
    
    /**
     * Check if currently dragging a piece
     */
    public function isDragging():Bool {
        return isPieceDragging;
    }
    
    /**
     * Set callback for when a move completes
     */
    public function setOnMoveComplete(callback:Void->Void):Void {
        onMoveCompleteCallback = callback;
    }
    
    /**
     * Set callback for when selection changes
     */
    public function setOnSelectionChange(callback:Void->Void):Void {
        onSelectionChangeCallback = callback;
    }

    /**
     * Set callback for checking engine turn
     */
    public function setOnEngineTurn(callback:Void->Void):Void {
        onEngineTurnCallback = callback;
    }
    
    /**
     * Update the board container reference (for resize)
     */
    public function setBoardContainer(container:Sprite):Void {
        this.boardContainer = container;
    }

    public function setBoardViewPort(viewPort:BoardViewPort):Void {
        this.boardViewPort = viewPort;
    }

    public function setTileSize(size:Int):Void {
        if (size >= 1)
            tileSize = size;
    }

    /** Tile size used for hit-testing (matches `BoardRenderer` after resize). */
    function liveTile():Int {
        var ts = boardRenderer.getTileSize();
        return ts >= 1 ? ts : (tileSize >= 1 ? tileSize : 32);
    }

    /** Board width/height in squares from live data (avoids stale `GameConfig` vs `boardData`). */
    function liveBoardCR():{c:Int, r:Int} {
        var b = controller.getBoardData();
        if (b == null || b.length == 0)
            return {c: GameConfig.boardCols, r: GameConfig.boardRows};
        var nr = b.length;
        var row0 = b[0];
        var nc = row0 != null ? row0.length : GameConfig.boardCols;
        return {c: nc, r: nr};
    }

    /**
     * Map stage coordinates to a board cell, or null if outside the board pixel area.
     * Clamps to the drawn grid so edge pixels and non-square windows map reliably (small boards).
     */
    function stageToCell(stageX:Float, stageY:Float):Null<{col:Int, row:Int}> {
        if (boardContainer == null || boardViewPort == null)
            return null;
        var vpPt = boardViewPort.globalToLocal(new Point(stageX, stageY));
        if (vpPt.x < 0 || vpPt.y < 0 || vpPt.x >= boardViewPort.getClipWidth() || vpPt.y >= boardViewPort.getClipHeight())
            return null;
        var point = boardContainer.globalToLocal(new Point(stageX, stageY));
        var tw = liveTile();
        var dims = liveBoardCR();
        if (tw < 1 || dims.c < 1 || dims.r < 1)
            return null;
        var maxX = dims.c * tw;
        var maxY = dims.r * tw;
        if (point.x < 0 || point.y < 0 || point.x >= maxX || point.y >= maxY)
            return null;
        var px = Math.min(point.x, maxX - 1e-4);
        var py = Math.min(point.y, maxY - 1e-4);
        var col = Std.int(Math.floor(px / tw));
        var row = Std.int(Math.floor(py / tw));
        if (col < 0 || row < 0 || col >= dims.c || row >= dims.r)
            return null;
        return {col: col, row: row};
    }

    public function getTileUnderStagePoint(stageX:Float, stageY:Float):Null<{col:Int, row:Int}> {
        return stageToCell(stageX, stageY);
    }

    public function setHumanMayMoveCheck(check:Void->Bool):Void {
        humanMayMove = check;
    }

    public function setOnBoardLeftTap(handler:Int->Int->Void):Void {
        onBoardLeftTap = handler;
    }
    
    private function isTerminalGameState():Bool {
        var gs = controller.getGameState();
        return gs == "checkmate" || gs == "stalemate" || gs == "draw_repetition" || gs == "draw_material"
            || gs == "draw_no_royals" || gs == "win_white" || gs == "win_black";
    }

    private function onMouseDown(e:MouseEvent):Void {
        if (!enabled || isPieceDragging)
            return;

        var cell = stageToCell(e.stageX, e.stageY);
        if (cell == null)
            return;
        var col = cell.col;
        var row = cell.row;

        if (onBoardLeftTap != null)
            onBoardLeftTap(col, row);

        if (isAnimating)
            return;
        if (isTerminalGameState())
            return;
        if (humanMayMove != null && !humanMayMove())
            return;
        
        var boardData = controller.getBoardData();
        var pieceID = boardData[row][col];
        var currentTurn = controller.getCurrentTurn();
        var selectedTile = controller.getSelectedTile();
        var isSelected = selectedTile != null;
        
        // If clicking on own piece, start drag (whether or not something else is selected)
        if (pieceID != "" && pieceID.charAt(pieceID.length - 1) == currentTurn) {
            // Start potential drag
            dragStartTile = new Point(col, row);
            dragStartStageX = e.stageX;
            dragStartStageY = e.stageY;
            controller.handleSelect(col, row);
            
            // Create drag piece bitmap for potential drag
            dragPiece = pieceRenderer.createDragPiece(pieceID);
            if (dragPiece != null) {
                var tw = liveTile();
                dragPiece.x = e.stageX - tw / 2;
                dragPiece.y = e.stageY - tw / 2;
                dragPiece.visible = false; // Hidden until we actually drag
                stage.addChild(dragPiece);
                
                isPieceDragging = true;
                PieceCursor.setGrabbing();
                PieceCursor.sync(e.stageX, e.stageY);
                
                // Show move hints
                updateBoardHints();
            }
            return;
        }
        
        // If we reach here, clicking on empty square or enemy piece
        if (isSelected) {
            // There's already a selected piece - try to make a move via click
            var sCol = Std.int(selectedTile.x);
            var sRow = Std.int(selectedTile.y);
            tryMakeMove(sCol, sRow, col, row, true);
        }
    }
    
    private function onMouseMove(e:MouseEvent):Void {
        if (!enabled) {
            PieceCursor.setAuto();
            return;
        }

        if (isPieceDragging && dragPiece != null) {
            PieceCursor.setGrabbing();
            PieceCursor.sync(e.stageX, e.stageY);

            // Calculate distance moved from start position
            var dx = e.stageX - dragStartStageX;
            var dy = e.stageY - dragStartStageY;
            var distance = Math.sqrt(dx * dx + dy * dy);
            var dragThresh = Math.max(4.0, liveTile() * 0.12);

            // Only show drag piece if moved enough (to distinguish from click)
            if (distance > dragThresh) {
                dragPiece.visible = true;
                // Hide the original piece during drag
                pieceRenderer.hidePieceAt(Std.int(dragStartTile.y), Std.int(dragStartTile.x));
            }

            var twm = liveTile();
            dragPiece.x = e.stageX - twm / 2;
            dragPiece.y = e.stageY - twm / 2;
            return;
        }

        updateHoverPieceCursor(e.stageX, e.stageY);
    }

    function updateHoverPieceCursor(stageX:Float, stageY:Float):Void {
        if (isAnimating || isTerminalGameState()) {
            PieceCursor.setAuto();
            return;
        }
        if (humanMayMove != null && !humanMayMove()) {
            PieceCursor.setAuto();
            return;
        }

        var cell = stageToCell(stageX, stageY);
        if (cell == null) {
            PieceCursor.setAuto();
            return;
        }
        var col = cell.col;
        var row = cell.row;

        var boardData = controller.getBoardData();
        var pieceID = boardData[row][col];
        var currentTurn = controller.getCurrentTurn();
        if (pieceID != "" && pieceID.charAt(pieceID.length - 1) == currentTurn) {
            PieceCursor.setGrab();
            PieceCursor.sync(stageX, stageY);
        } else {
            PieceCursor.setAuto();
        }
    }
    
    private function onMouseUp(e:MouseEvent):Void {
        if (!enabled) return;
        
        if (!isPieceDragging) {
            return;
        }
        
        // Store the start position before any operations
        var startCol = Std.int(dragStartTile.x);
        var startRow = Std.int(dragStartTile.y);
        
        var drop = stageToCell(e.stageX, e.stageY);
        var col = drop != null ? drop.col : -1;
        var row = drop != null ? drop.row : -1;
        
        // Check if this was actually a drag or just a click
        var wasDrag = (dragPiece != null && dragPiece.visible);
        
        // Clean up drag piece
        if (dragPiece != null) {
            stage.removeChild(dragPiece);
            dragPiece = null;
        }
        isPieceDragging = false;
        PieceCursor.setAuto();
        updateHoverPieceCursor(e.stageX, e.stageY);

        // If piece wasn't visible, it was a click (not a drag)
        if (!wasDrag) {
            // Same-square release: keep selection and redraw board hints (do not render(null,null) — that clears selection while the controller still has one).
            if (col == startCol && row == startRow) {
                updateBoardHints();
            }
            return;
        }
        
        var dims = liveBoardCR();
        if (col < 0 || col >= dims.c || row < 0 || row >= dims.r) {
            // Invalid drop location - restore board but keep selection visible
            restoreBoardWithSelection();
            return;
        }
        
        // Check if dropping on the same square
        if (col == startCol && row == startRow) {
            // Same square - just re-render with selection visible
            restoreBoardWithSelection();
            return;
        }
        
        // Try to make the move via drag
        if (humanMayMove != null && !humanMayMove()) {
            restoreBoardWithSelection();
            return;
        }
        if (isTerminalGameState()) {
            restoreBoardWithSelection();
            return;
        }
        tryMakeMove(startCol, startRow, col, row, false);
    }
    
    /** @param playPieceAnimation `true` for select-then-click; `false` for drag-and-drop. */
    private function tryMakeMove(startCol:Int, startRow:Int, endCol:Int, endRow:Int, playPieceAnimation:Bool = true):Void {
        if (humanMayMove != null && !humanMayMove()) {
            restoreBoardWithSelection();
            return;
        }
        if (isTerminalGameState()) {
            restoreBoardWithSelection();
            return;
        }
        var boardBefore = BoardUtils.copyBoard(controller.getBoardData());
        var pieceID = boardBefore[startRow][startCol];
        
        // Check if this is a capture before the move
        var isCapture = boardBefore[endRow][endCol] != "";
        var ep = BoardUtils.enPassantCaptureSquare(boardBefore, startCol, startRow, endCol, endRow, pieceID);
        
        if (controller.attemptMove(endCol, endRow)) {
            // Check if this is a promotion move
            if (controller.isPendingPromotion()) {
                pieceRenderer.render(controller.getBoardData());
                boardRenderer.setCheckHighlights(controller.getCheckedRoyals());
                boardRenderer.render(null, null, null, controller.getLastMoveHighlightFrom(), controller.getLastMoveHighlightTo());
                
                if (onSelectionChangeCallback != null) {
                    onSelectionChangeCallback();
                }
                return;
            }
            
            isAnimating = true;
            boardRenderer.setCheckHighlights(controller.getCheckedRoyals());
            boardRenderer.render(null, null, null, controller.getLastMoveHighlightFrom(), controller.getLastMoveHighlightTo());

            var parsed = BoardUtils.parsePieceId(pieceID);
            var sideFromDest = CastlingManager.instance != null
                ? CastlingManager.instance.getCastlingSideIfMove(parsed.color, boardBefore, startCol, startRow, endCol, endRow)
                : null;
            var looksLikeCastle = sideFromDest != null;
            var isCastling = looksLikeCastle;
            if (looksLikeCastle && SettingsConfig.allowIllegalMoves) {
                var kpc = PieceFactory.createPiece(pieceID);
                isCastling = kpc != null
                    && ValidationManager.isValidMove(kpc, new Point(startCol, startRow), new Point(endCol, endRow), boardBefore);
            }

            if (isCastling) {
                var rookCols = CastlingManager.instance != null
                    ? CastlingManager.instance.getCastlingRookColumns(parsed.color, sideFromDest, boardBefore, startCol)
                    : {startCol: (sideFromDest == "kingside" ? 7 : 0), endCol: (sideFromDest == "kingside" ? 5 : 3)};
                var rookStartC = rookCols.startCol;
                var rookEndC = rookCols.endCol;

                var sm = SoundManager.getInstance();
                var moveCh:SoundChannel = sm.playCastle();
                sm.playGameEndWithPrimaryMove(moveCh, controller.getMoveHistory().length, controller.getGameState());

                pieceRenderer.animateCastling(startRow, startCol, endRow, endCol, startRow, rookStartC, startRow, rookEndC, function() {
                    isAnimating = false;
                    finishMove();
                }, playPieceAnimation);
            } else {
                var gameState = controller.getGameState();
                var sm = SoundManager.getInstance();
                var moveCh:SoundChannel = null;
                if (gameState == "check" || gameState == "checkmate") {
                    moveCh = sm.playMove(true);
                } else if (isCapture || ep != null) {
                    moveCh = sm.playCapture();
                } else {
                    moveCh = sm.playMove(false);
                }
                sm.playGameEndWithPrimaryMove(moveCh, controller.getMoveHistory().length, gameState);

                if (ep != null) {
                    pieceRenderer.animateMove(startRow, startCol, endRow, endCol, pieceID, function() {
                        isAnimating = false;
                        finishMove();
                    }, Std.int(ep.y), Std.int(ep.x), playPieceAnimation);
                } else {
                    pieceRenderer.animateMove(startRow, startCol, endRow, endCol, pieceID, function() {
                        isAnimating = false;
                        finishMove();
                    }, null, null, playPieceAnimation);
                }
            }
        } else {
            // Invalid move - restore the board state with selection visible
            restoreBoardWithSelection();
        }
    }
    
    private function finishMove():Void {
        pieceRenderer.render(controller.getBoardData());
        boardRenderer.setCheckHighlights(controller.getCheckedRoyals());
        boardRenderer.render(controller.getSelectedTile(), null, null, controller.getLastMoveHighlightFrom(), controller.getLastMoveHighlightTo());
        
        if (onMoveCompleteCallback != null) {
            onMoveCompleteCallback();
        }
        
        // Check if engine should play
        if (onEngineTurnCallback != null) {
            onEngineTurnCallback();
        }
    }
    
    private function restoreBoardWithSelection():Void {
        pieceRenderer.render(controller.getBoardData());
        var hints = controller.getLegalMovesForSelection();
        var captureHints = controller.getCaptureMovesForSelection();
        boardRenderer.setCheckHighlights(controller.getCheckedRoyals());
        boardRenderer.render(controller.getSelectedTile(), hints, captureHints, controller.getLastMoveHighlightFrom(), controller.getLastMoveHighlightTo());
    }
    
    private function updateBoardHints():Void {
        var hints = controller.getLegalMovesForSelection();
        var captureHints = controller.getCaptureMovesForSelection();
        boardRenderer.setCheckHighlights(controller.getCheckedRoyals());
        boardRenderer.render(controller.getSelectedTile(), hints, captureHints, controller.getLastMoveHighlightFrom(), controller.getLastMoveHighlightTo());
        
        if (onSelectionChangeCallback != null) {
            onSelectionChangeCallback();
        }
    }
    
    /**
     * Handle promotion completion (call from external when promotion finishes)
     */
    public function onPromotionCompleted():Void {
        var sm = SoundManager.getInstance();
        var promoCh = sm.playPromote();
        sm.playGameEndWithPrimaryMove(promoCh, controller.getMoveHistory().length, controller.getGameState());
        
        // Re-render the board with the promoted piece
        pieceRenderer.render(controller.getBoardData());
        boardRenderer.setCheckHighlights(controller.getCheckedRoyals());
        boardRenderer.render(controller.getSelectedTile(), null, null, controller.getLastMoveHighlightFrom(), controller.getLastMoveHighlightTo());
        
        if (onSelectionChangeCallback != null) {
            onSelectionChangeCallback();
        }
    }
}