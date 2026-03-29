package ui;

import openfl.display.Sprite;
import openfl.display.Shape;
import openfl.events.MouseEvent;
import openfl.text.TextField;
import openfl.text.TextFormat;

/**
 * A modal menu for pawn promotion selection
 * Displays 4 pieces: Queen, Rook, Bishop, Knight with piece images
 */
class PromotionMenu extends Sprite {
    private var bgDim:Shape;
    private var container:Sprite;
    private var selectedPiece:String;
    private var onSelectCallback:String->Void;
    
    private var queenBtn:PromotionButton;
    private var rookBtn:PromotionButton;
    private var bishopBtn:PromotionButton;
    private var knightBtn:PromotionButton;
    private var playerColor:String = "w";
    
    public function new() {
        super();
        
        // Semi-transparent overlay
        bgDim = new Shape();
        bgDim.graphics.beginFill(0x000000, 0.5);
        bgDim.graphics.drawRect(0, 50, 680, 662); // Cover entire stage except top bar, so you can quit if needed.
        bgDim.graphics.endFill();
        addChild(bgDim);
        
        // Container for the menu
        container = new Sprite();
        addChild(container);
        
        // Draw menu background
        var menuBg = new Shape();
        menuBg.graphics.beginFill(0x2A2A2A);
        menuBg.graphics.drawRoundRect(0, 0, 300, 220, 12, 12);
        menuBg.graphics.endFill();
        
        // Draw border
        menuBg.graphics.lineStyle(2, 0x555555);
        menuBg.graphics.drawRoundRect(0, 0, 300, 220, 12, 12);
        container.addChild(menuBg);
        
        // Title
        var title = new TextField();
        title.defaultTextFormat = new TextFormat("Arial", 16, 0xFFFFFF, true);
        title.text = "Promote to:";
        title.selectable = false;
        title.width = 300;
        title.height = 30;
        title.x = 0;
        title.y = 10;
        container.addChild(title);
        
        // Create 4 buttons in a grid
        var btnSize = 50;
        var btnSpacing = 10;
        var startX = (300 - (btnSize * 2 + btnSpacing)) / 2;
        var startY = 50;
        
        // Queen button (top-left)
        queenBtn = new PromotionButton("queen", playerColor, btnSize);
        queenBtn.x = startX;
        queenBtn.y = startY;
        container.addChild(queenBtn);
        queenBtn.setOnClick(onQueenSelected);
        
        // Rook button (top-right)
        rookBtn = new PromotionButton("rook", playerColor, btnSize);
        rookBtn.x = startX + btnSize + btnSpacing;
        rookBtn.y = startY;
        container.addChild(rookBtn);
        rookBtn.setOnClick(onRookSelected);
        
        // Bishop button (bottom-left)
        bishopBtn = new PromotionButton("bishop", playerColor, btnSize);
        bishopBtn.x = startX;
        bishopBtn.y = startY + btnSize + btnSpacing;
        container.addChild(bishopBtn);
        bishopBtn.setOnClick(onBishopSelected);
        
        // Knight button (bottom-right)
        knightBtn = new PromotionButton("knight", playerColor, btnSize);
        knightBtn.x = startX + btnSize + btnSpacing;
        knightBtn.y = startY + btnSize + btnSpacing;
        container.addChild(knightBtn);
        knightBtn.setOnClick(onKnightSelected);
        
        // Center the container
        container.x = (680 - 300) / 2;
        container.y = (712 - 220) / 2;
        
        visible = false;
    }
    
    public function show(callback:String->Void, playerColor:String = "w"):Void {
        this.playerColor = playerColor;
        onSelectCallback = callback;
        visible = true;
        // Ensure buttons are interactive
        mouseChildren = true;
        mouseEnabled = true;
        
        // Recreate buttons with correct player color
        recreateButtons();
    }
    
    public function hide():Void {
        visible = false;
        mouseEnabled = false;
    }
    
    private function recreateButtons():Void {
        var btnSize = 50;
        var btnSpacing = 10;
        var startX = (300 - (btnSize * 2 + btnSpacing)) / 2;
        var startY = 50;
        
        // Remove old buttons
        if (container.contains(queenBtn)) container.removeChild(queenBtn);
        if (container.contains(rookBtn)) container.removeChild(rookBtn);
        if (container.contains(bishopBtn)) container.removeChild(bishopBtn);
        if (container.contains(knightBtn)) container.removeChild(knightBtn);
        
        // Queen button (top-left)
        queenBtn = new PromotionButton("queen", playerColor, btnSize);
        queenBtn.x = startX;
        queenBtn.y = startY;
        container.addChild(queenBtn);
        queenBtn.setOnClick(onQueenSelected);
        
        // Rook button (top-right)
        rookBtn = new PromotionButton("rook", playerColor, btnSize);
        rookBtn.x = startX + btnSize + btnSpacing;
        rookBtn.y = startY;
        container.addChild(rookBtn);
        rookBtn.setOnClick(onRookSelected);
        
        // Bishop button (bottom-left)
        bishopBtn = new PromotionButton("bishop", playerColor, btnSize);
        bishopBtn.x = startX;
        bishopBtn.y = startY + btnSize + btnSpacing;
        container.addChild(bishopBtn);
        bishopBtn.setOnClick(onBishopSelected);
        
        // Knight button (bottom-right)
        knightBtn = new PromotionButton("knight", playerColor, btnSize);
        knightBtn.x = startX + btnSize + btnSpacing;
        knightBtn.y = startY + btnSize + btnSpacing;
        container.addChild(knightBtn);
        knightBtn.setOnClick(onKnightSelected);
    }
    
    private function onQueenSelected():Void {
        if (onSelectCallback != null) {
            onSelectCallback("queen");
        }
        hide();
    }
    
    private function onRookSelected():Void {
        if (onSelectCallback != null) {
            onSelectCallback("rook");
        }
        hide();
    }
    
    private function onBishopSelected():Void {
        if (onSelectCallback != null) {
            onSelectCallback("bishop");
        }
        hide();
    }
    
    private function onKnightSelected():Void {
        if (onSelectCallback != null) {
            onSelectCallback("knight");
        }
        hide();
    }
}
