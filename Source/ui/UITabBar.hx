package ui;

import openfl.display.Sprite;
import openfl.display.Shape;
import openfl.events.MouseEvent;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.text.TextFormatAlign;

/**
 * A tab bar component for switching between different views
 */
class UITabBar extends Sprite {
    private var tabs:Array<TabInfo>;
    private var tabWidth:Int;
    private var tabHeight:Int;
    private var activeIndex:Int;
    private var onTabChangeCallback:Int->Void;
    private var tabSprites:Array<Sprite>;
    private var bgColor:Int;
    private var activeBgColor:Int;
    private var hoverColor:Int;
    private var borderColor:Int;
    
    public function new(tabWidth:Int = 80, tabHeight:Int = 32) {
        super();
        
        this.tabs = [];
        this.tabSprites = [];
        this.tabWidth = tabWidth;
        this.tabHeight = tabHeight;
        this.activeIndex = 0;
        this.bgColor = 0x2A2A2A;
        this.activeBgColor = 0x3A3A3A;
        this.hoverColor = 0x444444;
        this.borderColor = 0x555555;
    }
    
    /**
     * Add a tab to the bar
     */
    public function addTab(label:String):Void {
        tabs.push({ label: label });
        createTabSprite(tabs.length - 1);
        redraw();
    }
    
    /**
     * Create a sprite for a tab
     */
    private function createTabSprite(index:Int):Void {
        var tabSprite = new Sprite();
        tabSprite.buttonMode = true;
        tabSprite.useHandCursor = true;
        
        var bg = new Shape();
        tabSprite.addChild(bg);
        
        // Create text field
        var tf = new TextField();
        tf.defaultTextFormat = new TextFormat("Arial", 12, 0xFFFFFF, true, null, null, null, null, TextFormatAlign.CENTER);
        tf.text = tabs[index].label;
        tf.selectable = false;
        tf.width = tabWidth;
        tf.height = tabHeight;
        tf.y = (tabHeight - tf.textHeight) / 2 - 2;
        tabSprite.addChild(tf);
        
        // Position the tab
        tabSprite.x = index * tabWidth;
        tabSprite.y = 0;
        
        // Add click handler
        tabSprite.addEventListener(MouseEvent.CLICK, function(e:MouseEvent) {
            setActiveTab(index);
        });
        
        // Add hover effects
        tabSprite.addEventListener(MouseEvent.MOUSE_OVER, function(e:MouseEvent) {
            if (activeIndex != index) {
                var bgShape:Shape = cast tabSprite.getChildAt(0);
                bgShape.graphics.clear();
                bgShape.graphics.beginFill(hoverColor);
                bgShape.graphics.drawRect(0, 0, tabWidth, tabHeight);
                bgShape.graphics.endFill();
            }
        });
        
        tabSprite.addEventListener(MouseEvent.MOUSE_OUT, function(e:MouseEvent) {
            redrawTab(index);
        });
        
        tabSprites.push(tabSprite);
        addChild(tabSprite);
    }
    
    /**
     * Redraw all tabs
     */
    private function redraw():Void {
        for (i in 0...tabSprites.length) {
            redrawTab(i);
        }
    }
    
    /**
     * Redraw a specific tab
     */
    private function redrawTab(index:Int):Void {
        if (index >= tabSprites.length) return;
        
        var tabSprite = tabSprites[index];
        var bg:Shape = cast tabSprite.getChildAt(0);
        
        bg.graphics.clear();
        
        if (index == activeIndex) {
            // Active tab - lighter background with bottom border
            bg.graphics.beginFill(activeBgColor);
            bg.graphics.drawRect(0, 0, tabWidth, tabHeight);
            bg.graphics.endFill();
            
            // Bottom highlight line
            bg.graphics.beginFill(0x4CAF50);
            bg.graphics.drawRect(0, tabHeight - 3, tabWidth, 3);
            bg.graphics.endFill();
        } else {
            // Inactive tab
            bg.graphics.beginFill(bgColor);
            bg.graphics.drawRect(0, 0, tabWidth, tabHeight);
            bg.graphics.endFill();
        }
    }
    
    /**
     * Set the active tab
     */
    public function setActiveTab(index:Int):Void {
        if (index < 0 || index >= tabs.length) return;
        
        var oldIndex = activeIndex;
        activeIndex = index;
        
        redraw();
        
        if (onTabChangeCallback != null && oldIndex != index) {
            onTabChangeCallback(index);
        }
    }
    
    /**
     * Get the active tab index
     */
    public function getActiveTab():Int {
        return activeIndex;
    }
    
    /**
     * Set the callback for when tab changes
     */
    public function setOnTabChange(callback:Int->Void):Void {
        onTabChangeCallback = callback;
    }
    
    /**
     * Get total width of the tab bar
     */
    public function getBarWidth():Int {
        return tabs.length * tabWidth;
    }

    /** Split `totalW` evenly across tabs (min 48px per tab). Call after all tabs are added. */
    public function setStretchWidth(totalW:Int):Void {
        if (tabs.length == 0)
            return;
        tabWidth = Std.int(Math.max(48, totalW / tabs.length));
        for (i in 0...tabSprites.length) {
            var tabSprite = tabSprites[i];
            tabSprite.x = i * tabWidth;
            var bg:Shape = cast tabSprite.getChildAt(0);
            var tf:TextField = cast tabSprite.getChildAt(1);
            tf.width = tabWidth;
            tf.y = (tabHeight - tf.textHeight) / 2 - 2;
            redrawTab(i);
        }
    }
    
    /**
     * Get tab height
     */
    public function getTabHeight():Int {
        return tabHeight;
    }
}

// Helper class for tab info
private typedef TabInfo = {
    var label:String;
}