package ui;

import openfl.display.Sprite;
import openfl.display.Shape;

/**
 * A UI panel with rounded corners, outline, and title bar with control buttons
 * Used as a container for UI elements
 */
class UIPanel extends Sprite {
    private var _panelWidth:Int;
    private var _panelHeight:Int;
    private var cornerRadius:Int;
    private var bgColor:Int;
    private var borderColor:Int;
    private var borderThickness:Int;
    private var padding:Int;
    private var titleBarHeight:Int = 32;
    private var titleBarArea:Sprite;
    
    private var minimizeBtn:UIButton;
    private var closeBtn:UIButton;
    
    public function new(panelWidth:Int, panelHeight:Int, bgColor:Int = 0x2A2A2A, borderColor:Int = 0x444444, 
                        cornerRadius:Int = 16, borderThickness:Int = 2, padding:Int = 16) {
        super();
        
        this._panelWidth = panelWidth;
        this._panelHeight = panelHeight;
        this.bgColor = bgColor;
        this.borderColor = borderColor;
        this.cornerRadius = cornerRadius;
        this.borderThickness = borderThickness;
        this.padding = padding;
        
        draw();
        createTitleBar();
    }
    
    private function draw():Void {
        // Draw border
        var border = new Shape();
        border.graphics.lineStyle(borderThickness, borderColor);
        border.graphics.beginFill(bgColor);
        border.graphics.drawRoundRect(0, 0, _panelWidth, _panelHeight, cornerRadius, cornerRadius);
        border.graphics.endFill();
        
        addChild(border);
    }
    
    private function createTitleBar():Void {
        // Create draggable title bar background
        titleBarArea = new Sprite();
        titleBarArea.buttonMode = true;
        titleBarArea.useHandCursor = true;
        
        var titleBar = new Shape();
        titleBar.graphics.beginFill(0x1A1A1A, 0); // Invisible (alpha = 0)
        titleBar.graphics.drawRoundRect(0, 0, _panelWidth, titleBarHeight, cornerRadius, 0);
        titleBar.graphics.endFill();
        titleBarArea.addChild(titleBar);
        
        // Add invisible hit area for dragging (covers full width except buttons area)
        var dragArea = new Shape();
        dragArea.graphics.beginFill(0x000000, 0); // Invisible
        dragArea.graphics.drawRect(0, 0, _panelWidth - 100, titleBarHeight); // Leave room for buttons
        dragArea.graphics.endFill();
        titleBarArea.addChild(dragArea);
        
        addChild(titleBarArea);
        
        // Store buttons as public so they can be moved elsewhere
        var btnSize = 24;
        var btnSpacing = 8;
        
        // Close button (red) with X icon - will be positioned by caller
        closeBtn = new UIButton(btnSize, btnSize, "", 0xD32F2F, 0xFF5252, "close");
        addChild(closeBtn);
        
        // Minimize button with line icon - will be positioned by caller
        minimizeBtn = new UIButton(btnSize, btnSize, "", 0x444444, 0x666666, "minimize");
        addChild(minimizeBtn);
    }
    
    /**
     * Get the title bar sprite for setting up dragging
     */
    public function getTitleBarArea():Sprite {
        return titleBarArea;
    }
    
    /**
     * Position the buttons at the given coordinates
     */
    public function positionButtons(x:Int, y:Int):Void {
        var btnSize = 24;
        var btnSpacing = 8;
        minimizeBtn.x = x;
        minimizeBtn.y = y;
        closeBtn.x = x + btnSize + btnSpacing;
        closeBtn.y = y;
    }
    
    /**
     * Get the title bar height
     */
    public function getTitleBarHeight():Int {
        return titleBarHeight;
    }
    
    /**
     * Get the close button to register click handlers
     */
    public function getCloseButton():UIButton {
        return closeBtn;
    }
    
    /**
     * Get the minimize button to register click handlers
     */
    public function getMinimizeButton():UIButton {
        return minimizeBtn;
    }
    
    /**
     * Get the padding (inner margin)
     */
    public function getPadding():Int {
        return padding;
    }
    
    /**
     * Get usable content width (accounting for padding)
     */
    public function getContentWidth():Int {
        return _panelWidth - (padding * 2);
    }
    
    /**
     * Get usable content height (accounting for padding and title bar)
     */
    public function getContentHeight():Int {
        return _panelHeight - (padding * 2) - titleBarHeight;
    }
    
    /**
     * Get padding-adjusted x position
     */
    public function getContentX():Int {
        return padding;
    }
    
    /**
     * Get padding-adjusted y position (below title bar)
     */
    public function getContentY():Int {
        return padding + titleBarHeight;
    }
}
