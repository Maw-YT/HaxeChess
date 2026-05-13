package ui;

import openfl.display.Sprite;
import openfl.display.Shape;

/**
 * Rectangular panel with optional tab bar (fills window; content uses integer layout from Main).
 */
class UIPanel extends Sprite {
    private var _panelWidth:Int;
    private var _panelHeight:Int;
    private var bgColor:Int;
    private var borderColor:Int;
    private var borderThickness:Int;
    private var padding:Int;
    private var tabBarHeight:Int = 32;
    private var tabBar:UITabBar;
    private var useTabs:Bool;
    private var bgShape:Shape;

    public function new(panelWidth:Int, panelHeight:Int, bgColor:Int = 0x2A2A2A, borderColor:Int = 0x444444,
            borderThickness:Int = 2, padding:Int = 16, useTabs:Bool = false) {
        super();

        this._panelWidth = panelWidth;
        this._panelHeight = panelHeight;
        this.bgColor = bgColor;
        this.borderColor = borderColor;
        this.borderThickness = borderThickness;
        this.padding = padding;
        this.useTabs = useTabs;

        draw();
        if (useTabs) {
            tabBar = new UITabBar(80, tabBarHeight);
            tabBar.x = padding;
            tabBar.y = padding;
            addChild(tabBar);
        }
    }

    /** Resize background to match the window; stretch tabs via `UITabBar.setStretchWidth` if needed. */
    public function resize(panelWidth:Int, panelHeight:Int):Void {
        _panelWidth = panelWidth;
        _panelHeight = panelHeight;
        draw();
    }

    private function draw():Void {
        if (bgShape == null) {
            bgShape = new Shape();
            addChildAt(bgShape, 0);
        }
        bgShape.graphics.clear();
        bgShape.graphics.lineStyle(borderThickness, borderColor);
        bgShape.graphics.beginFill(bgColor);
        bgShape.graphics.drawRect(0, 0, _panelWidth, _panelHeight);
        bgShape.graphics.endFill();
    }

    public function getPadding():Int {
        return padding;
    }

    public function getContentWidth():Int {
        return _panelWidth - (padding * 2);
    }

    public function getContentHeight():Int {
        var chromeTop = useTabs ? (padding + tabBarHeight) : 0;
        return _panelHeight - (padding * 2) - chromeTop;
    }

    public function getContentX():Int {
        return padding;
    }

    /** Y offset of main content (below tab bar when tabs are enabled). */
    public function getContentY():Int {
        return useTabs ? (padding + tabBarHeight + padding) : padding;
    }

    public function getTabBar():UITabBar {
        return tabBar;
    }

    public function hasTabs():Bool {
        return useTabs;
    }
}
