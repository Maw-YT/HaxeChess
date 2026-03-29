package;

import openfl.display.Sprite;
import openfl.display.StageDisplayState;
import openfl.events.MouseEvent;
import openfl.events.Event;
import openfl.geom.Point;
import interfaces.IGameController;
import config.GameConfig;
import ui.UIPanel;
import ui.UILayout;

/**
 * Main entry point for the chess game
 */
class Main extends Sprite {
    private var tileSize:Int;
    private var controller:IGameController;
    private var boardRenderer:interfaces.IBoardRenderer;
    private var pieceRenderer:interfaces.IPieceRenderer;
    private var isAnimating:Bool = false;
    
    private var boardContainer:Sprite;
    private var uiPanel:UIPanel;
    private var panelPadding:Int = 20;
    private var turnLabel:openfl.text.TextField;
    
    private var isDragging:Bool = false;
    private var dragStartX:Float = 0;
    private var dragStartY:Float = 0;

    public function new() {
        super();
        
        tileSize = GameConfig.DEFAULT_TILE_SIZE;
        
        // Make stage background transparent
        stage.color = 0x00000000; // Fully transparent
        
        // Initialize game components
        controller = new controllers.GameController();
        boardRenderer = new renderers.BoardRenderer(tileSize);
        pieceRenderer = new renderers.PieceRenderer(tileSize);

        // Initial setup
        setupUI();
        
        // Add promotion menu to the top layer (after UI so it's on top)
        var promotionMenu = controller.getPromotionMenu();
        if (contains(promotionMenu)) removeChild(promotionMenu);
        addChild(promotionMenu);
        
        // Register promotion completion callback
        controller.setOnPromotionCompleted(onPromotionCompleted);
        
        // Setup input handling
        stage.addEventListener(MouseEvent.CLICK, onClick);
        stage.addEventListener(Event.RESIZE, onResize);
    }
    
    private function setupUI():Void {
        // Remove old UI if it exists
        if (uiPanel != null && contains(uiPanel)) removeChild(uiPanel);
        if (boardContainer != null && contains(boardContainer)) removeChild(boardContainer);
        if (turnLabel != null && contains(turnLabel)) removeChild(turnLabel);
        
        var boardSize = tileSize * GameConfig.BOARD_SIZE;
        var panelWidth = boardSize + (panelPadding * 2);
        var panelHeight = boardSize + (panelPadding * 2) + 32; // +32 for title bar height (invisible but still there)
        
        // Create UI Panel (rounded rectangle container with title bar) - fill entire window
        uiPanel = new UIPanel(panelWidth, panelHeight, 0x1A1A1A, 0x555555, 16, 2, panelPadding);
        uiPanel.x = 0;
        uiPanel.y = 0;
        addChild(uiPanel);
        
        // Setup button callbacks and position them at top-right
        uiPanel.getCloseButton().setOnClick(onCloseWindow);
        uiPanel.getMinimizeButton().setOnClick(onMinimizeWindow);
        uiPanel.positionButtons(panelWidth - 70, 8); // Top-right corner with proper margin
        
        // Setup title bar dragging
        var titleBar = uiPanel.getTitleBarArea();
        titleBar.addEventListener(MouseEvent.MOUSE_DOWN, onTitleBarMouseDown);
        
        // Create turn label
        turnLabel = new openfl.text.TextField();
        turnLabel.defaultTextFormat = new openfl.text.TextFormat("Arial", 14, 0xFFFFFF, true);
        turnLabel.selectable = false;
        turnLabel.width = 100;
        turnLabel.height = 30;
        turnLabel.x = panelPadding + 10;
        turnLabel.y = 6;
        updateTurnLabel();
        addChild(turnLabel);
        
        // Create board container inside the panel
        boardContainer = new Sprite();
        boardContainer.x = uiPanel.x + uiPanel.getContentX();
        boardContainer.y = uiPanel.y + uiPanel.getContentY();
        addChild(boardContainer);
        
        // Add board and pieces to the board container
        if (!boardContainer.contains(cast boardRenderer)) {
            boardContainer.addChild(cast boardRenderer);
        }
        if (!boardContainer.contains(cast pieceRenderer)) {
            boardContainer.addChild(cast pieceRenderer);
        }

        // Initial render
        boardRenderer.render(null, null);
        pieceRenderer.render(controller.getBoardData());
    }
    
    private function updateTurnLabel():Void {
        if (turnLabel != null) {
            var turnColor = controller.getCurrentTurn() == "w" ? "White" : "Black";
            turnLabel.text = "Turn: " + turnColor;
        }
    }
    
    private function onPromotionCompleted():Void {
        // Re-render the board with the promoted piece
        pieceRenderer.render(controller.getBoardData());
        boardRenderer.render(controller.getSelectedTile());
        updateTurnLabel();
    }
    
    private function onTitleBarMouseDown(e:MouseEvent):Void {
        isDragging = true;
        dragStartX = e.stageX;
        dragStartY = e.stageY;
        
        stage.addEventListener(MouseEvent.MOUSE_MOVE, onTitleBarMouseMove);
        stage.addEventListener(MouseEvent.MOUSE_UP, onTitleBarMouseUp);
    }
    
    private function onTitleBarMouseMove(e:MouseEvent):Void {
        if (isDragging) {
            #if (windows || mac || linux)
            var deltaX = e.stageX - dragStartX;
            var deltaY = e.stageY - dragStartY;
            
            if (stage.nativeWindow != null) {
                stage.nativeWindow.x = Std.int(stage.nativeWindow.x + deltaX);
                stage.nativeWindow.y = Std.int(stage.nativeWindow.y + deltaY);
            }
            #end
        }
    }
    
    private function onTitleBarMouseUp(e:MouseEvent):Void {
        isDragging = false;
        stage.removeEventListener(MouseEvent.MOUSE_MOVE, onTitleBarMouseMove);
        stage.removeEventListener(MouseEvent.MOUSE_UP, onTitleBarMouseUp);
    }
    
    private function onCloseWindow():Void {
        #if sys
        Sys.exit(0);
        #end
    }
    
    private function onMinimizeWindow():Void {
        #if windows
        if (stage.nativeWindow != null) {
            stage.nativeWindow.minimize();
        }
        #elseif mac
        if (stage.nativeWindow != null) {
            stage.nativeWindow.minimize();
        }
        #elseif linux
        if (stage.nativeWindow != null) {
            stage.nativeWindow.minimize();
        }
        #end
    }
    
    private function onResize(e:Event):Void {
        setupUI();
        
        // Ensure promotion menu is on top after resize
        var promotionMenu = controller.getPromotionMenu();
        if (contains(promotionMenu)) removeChild(promotionMenu);
        addChild(promotionMenu);
    }

    private function onClick(e:MouseEvent):Void {
        if (isAnimating) return;

        // Get the relative position within the board container
        var point = boardContainer.globalToLocal(new Point(e.stageX, e.stageY));
        var boardX = point.x;
        var boardY = point.y;
        
        var col = Math.floor(boardX / tileSize);
        var row = Math.floor(boardY / tileSize);
        
        // Only process clicks within the board
        if (col < 0 || col >= GameConfig.BOARD_SIZE || row < 0 || row >= GameConfig.BOARD_SIZE) {
            return;
        }

        if (controller.getSelectedTile() == null) {
            // Try to select a piece
            if (controller.handleSelect(col, row)) {
                var hints = controller.getLegalMovesForSelection();
                boardRenderer.render(controller.getSelectedTile(), hints);
            }
        } else {
            // Try to move the selected piece
            var selected = controller.getSelectedTile();
            var sR = Std.int(selected.y);
            var sC = Std.int(selected.x);
            var pieceID = controller.getBoardData()[sR][sC];

            if (controller.attemptMove(col, row)) {
                // Check if this is a promotion move (promotion menu is showing)
                if (controller.isPendingPromotion()) {
                    // Don't animate - we're waiting for promotion selection
                    isAnimating = false;
                    boardRenderer.render(null, null);
                    return;
                }
                
                isAnimating = true;
                boardRenderer.render(null, null);

                // Check if this was a castling move (king moves 2 squares horizontally)
                var isCastling = pieceID.indexOf("king") == 0 && Math.abs(col - sC) == 2;
                
                if (isCastling) {
                    // Determine rook positions based on kingside or queenside castling
                    var rookStartC = (col > sC) ? 7 : 0;  // h-file or a-file
                    var rookEndC = (col > sC) ? 5 : 3;    // f-file or d-file
                    
                    pieceRenderer.animateCastling(sR, sC, row, col, sR, rookStartC, sR, rookEndC, function() {
                        isAnimating = false;
                        
                        pieceRenderer.render(controller.getBoardData());
                        boardRenderer.render(controller.getSelectedTile());
                        updateTurnLabel();
                    });
                } else {
                    // Standard move animation
                    pieceRenderer.animateMove(sR, sC, row, col, pieceID, function() {
                        isAnimating = false;
                        pieceRenderer.render(controller.getBoardData());
                        boardRenderer.render(controller.getSelectedTile());
                        updateTurnLabel();
                    });
                }
            } else {
                controller.handleSelect(col, row); // Try selecting a different piece
                var hints = controller.getLegalMovesForSelection();
                boardRenderer.render(controller.getSelectedTile(), hints);
            }
        }
    }
}