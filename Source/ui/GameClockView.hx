package ui;

import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.text.TextFormatAlign;
import utils.IntBounds;

/** Rounded clock pills above/below the board (time digits only); colors ease toward active / idle state. */
class GameClockView {
    public static inline var CLOCK_PAD_V:Int = 8;
    public static inline var CLOCK_BAR_H:Int = 42;
    static inline var CLOCK_CORNER_R:Float = 12;

    static inline var CLK_GRAY_BG:Int = 0x3D3D42;
    static inline var CLK_GRAY_TX:Int = 0xA8A8B0;
    static inline var CLK_GRAY_BD:Int = 0x5C5C64;
    static inline var CLK_WHITE_HI_BG:Int = 0xF2F2F8;
    static inline var CLK_WHITE_HI_TX:Int = 0x101018;
    static inline var CLK_WHITE_HI_BD:Int = 0xC6C6D8;
    static inline var CLK_BLACK_HI_BG:Int = 0x141418;
    static inline var CLK_BLACK_HI_TX:Int = 0xF0F0F5;
    static inline var CLK_BLACK_HI_BD:Int = 0x4A4A55;

    public var blackRoot(default, null):Sprite;
    public var whiteRoot(default, null):Sprite;

    var blackBg:Shape;
    var whiteBg:Shape;
    var blackTf:TextField;
    var whiteTf:TextField;
    var clockBarW:Int = 0;

    var lastVisualFrameStamp:Float = -1.0;
    var wClockFill:Int;
    var wClockText:Int;
    var wClockBrd:Int;
    var bClockFill:Int;
    var bClockText:Int;
    var bClockBrd:Int;

    var wClockFillT:Int;
    var wClockTextT:Int;
    var wClockBrdT:Int;
    var bClockFillT:Int;
    var bClockTextT:Int;
    var bClockBrdT:Int;

    public function new() {}

    public static function verticalInsetTimed():Int {
        return CLOCK_BAR_H + CLOCK_PAD_V;
    }

    public function clearFrom(parent:Sprite):Void {
        if (blackRoot != null && parent.contains(blackRoot))
            parent.removeChild(blackRoot);
        if (whiteRoot != null && parent.contains(whiteRoot))
            parent.removeChild(whiteRoot);
        blackRoot = null;
        whiteRoot = null;
        blackBg = null;
        whiteBg = null;
        blackTf = null;
        whiteTf = null;
        lastVisualFrameStamp = -1.0;
    }

    /**
     * @param boardW board width in pixels (files × tile)
     * @param boardH board height in pixels (ranks × tile)
     * @param pillWidth visual width of each clock pill (narrower than board).
     */
    public function rebuild(parent:Sprite, boardX:Float, boardY:Float, boardW:Int, boardH:Int, timed:Bool, pillWidth:Int):Void {
        clearFrom(parent);
        if (!timed)
            return;

        clockBarW = IntBounds.clampi(pillWidth, 96, boardW - 8);
        var tfSize = 22;
        var padX = 8;

        var fmt = new TextFormat("_sans", tfSize, CLK_GRAY_TX, true);
        fmt.align = TextFormatAlign.CENTER;

        blackRoot = new Sprite();
        blackBg = new Shape();
        blackRoot.addChild(blackBg);
        blackTf = new TextField();
        blackTf.embedFonts = false;
        blackTf.selectable = false;
        blackTf.multiline = false;
        blackTf.wordWrap = false;
        blackTf.defaultTextFormat = fmt;
        blackTf.x = padX;
        blackTf.y = Std.int((CLOCK_BAR_H - tfSize) * 0.5) - 2;
        blackTf.width = clockBarW - padX * 2;
        blackTf.height = CLOCK_BAR_H;
        blackRoot.addChild(blackTf);
        blackRoot.x = boardX + boardW - clockBarW;
        blackRoot.y = boardY - CLOCK_BAR_H - CLOCK_PAD_V;
        parent.addChild(blackRoot);

        whiteRoot = new Sprite();
        whiteBg = new Shape();
        whiteRoot.addChild(whiteBg);
        whiteTf = new TextField();
        whiteTf.embedFonts = false;
        whiteTf.selectable = false;
        whiteTf.multiline = false;
        whiteTf.wordWrap = false;
        whiteTf.defaultTextFormat = fmt;
        whiteTf.x = padX;
        whiteTf.y = Std.int((CLOCK_BAR_H - tfSize) * 0.5) - 2;
        whiteTf.width = clockBarW - padX * 2;
        whiteTf.height = CLOCK_BAR_H;
        whiteRoot.addChild(whiteTf);
        whiteRoot.x = boardX + boardW - clockBarW;
        whiteRoot.y = boardY + boardH + CLOCK_PAD_V;
        parent.addChild(whiteRoot);

        wClockFill = bClockFill = CLK_GRAY_BG;
        wClockText = bClockText = CLK_GRAY_TX;
        wClockBrd = bClockBrd = CLK_GRAY_BD;
        redrawClockRoundRect(whiteBg, clockBarW, CLOCK_BAR_H, wClockFill, wClockBrd);
        redrawClockRoundRect(blackBg, clockBarW, CLOCK_BAR_H, bClockFill, bClockBrd);
        lastVisualFrameStamp = -1.0;
        wClockFillT = bClockFillT = CLK_GRAY_BG;
        wClockTextT = bClockTextT = CLK_GRAY_TX;
        wClockBrdT = bClockBrdT = CLK_GRAY_BD;
        applyClockTextColors();
    }

    public function setTexts(white:String, black:String):Void {
        if (whiteTf != null)
            whiteTf.text = white;
        if (blackTf != null)
            blackTf.text = black;
    }

    public function setRootsVisible(v:Bool):Void {
        if (whiteRoot != null)
            whiteRoot.visible = v;
        if (blackRoot != null)
            blackRoot.visible = v;
    }

    public function consumeFrameDtMs():Float {
        var now = haxe.Timer.stamp();
        var dtVis = (lastVisualFrameStamp < 0) ? 16.666 : Math.min(120.0, Math.max(0.0, (now - lastVisualFrameStamp) * 1000.0));
        lastVisualFrameStamp = now;
        return dtVis;
    }

    public function tickVisuals(dtMs:Float, style:ClockVisualStyle):Void {
        if (whiteRoot == null || blackRoot == null)
            return;
        if (!style.gameTab || style.initialMs <= 0)
            return;
        updateClockVisualTargetsFromStyle(style, false);
        wClockFill = stepColorToward(wClockFill, wClockFillT, dtMs);
        wClockText = stepColorToward(wClockText, wClockTextT, dtMs);
        wClockBrd = stepColorToward(wClockBrd, wClockBrdT, dtMs);
        bClockFill = stepColorToward(bClockFill, bClockFillT, dtMs);
        bClockText = stepColorToward(bClockText, bClockTextT, dtMs);
        bClockBrd = stepColorToward(bClockBrd, bClockBrdT, dtMs);
        redrawClockRoundRect(whiteBg, clockBarW, CLOCK_BAR_H, wClockFill, wClockBrd);
        redrawClockRoundRect(blackBg, clockBarW, CLOCK_BAR_H, bClockFill, bClockBrd);
        applyClockTextColors();
    }

    public function snapVisualsToTargets(style:ClockVisualStyle):Void {
        if (whiteRoot == null || blackRoot == null)
            return;
        if (style.initialMs <= 0)
            return;
        updateClockVisualTargetsFromStyle(style, true);
    }

    function redrawClockRoundRect(sh:Shape, w:Int, h:Int, fill:Int, brd:Int):Void {
        sh.graphics.clear();
        sh.graphics.lineStyle(2.5, brd, 1.0, true);
        sh.graphics.beginFill(fill);
        sh.graphics.drawRoundRect(0.5, 0.5, w - 1, h - 1, CLOCK_CORNER_R, CLOCK_CORNER_R);
        sh.graphics.endFill();
    }

    function stepColorToward(current:Int, target:Int, dtMs:Float):Int {
        var r0 = (current >> 16) & 0xFF;
        var g0 = (current >> 8) & 0xFF;
        var b0 = current & 0xFF;
        var r1 = (target >> 16) & 0xFF;
        var g1 = (target >> 8) & 0xFF;
        var b1 = target & 0xFF;
        var k = 1.0 - Math.pow(0.84, dtMs / 24.0);
        if (k > 1.0)
            k = 1.0;
        if (k < 0.0)
            k = 0.0;
        var r = Std.int(r0 + (r1 - r0) * k + 0.5);
        var g = Std.int(g0 + (g1 - g0) * k + 0.5);
        var b = Std.int(b0 + (b1 - b0) * k + 0.5);
        return (r << 16) | (g << 8) | b;
    }

    function updateClockVisualTargetsFromStyle(style:ClockVisualStyle, snap:Bool):Void {
        var wBgT = CLK_GRAY_BG;
        var wTxT = CLK_GRAY_TX;
        var wBrdT = CLK_GRAY_BD;
        var bBgT = CLK_GRAY_BG;
        var bTxT = CLK_GRAY_TX;
        var bBrdT = CLK_GRAY_BD;

        var liveGame = style.gameTab && style.initialMs > 0 && style.clocksStarted && !style.browsingHistory && !style.terminal
            && !style.timeoutActive;
        var preStart = style.gameTab && style.initialMs > 0 && !style.clocksStarted && !style.browsingHistory && !style.terminal
            && !style.timeoutActive;
        if (liveGame) {
            if (style.turnW) {
                wBgT = CLK_WHITE_HI_BG;
                wTxT = CLK_WHITE_HI_TX;
                wBrdT = CLK_WHITE_HI_BD;
                bBgT = CLK_GRAY_BG;
                bTxT = CLK_GRAY_TX;
                bBrdT = CLK_GRAY_BD;
            } else {
                bBgT = CLK_BLACK_HI_BG;
                bTxT = CLK_BLACK_HI_TX;
                bBrdT = CLK_BLACK_HI_BD;
                wBgT = CLK_GRAY_BG;
                wTxT = CLK_GRAY_TX;
                wBrdT = CLK_GRAY_BD;
            }
        } else if (preStart) {
            wBgT = CLK_WHITE_HI_BG;
            wTxT = CLK_WHITE_HI_TX;
            wBrdT = CLK_WHITE_HI_BD;
        }

        wClockFillT = wBgT;
        wClockTextT = wTxT;
        wClockBrdT = wBrdT;
        bClockFillT = bBgT;
        bClockTextT = bTxT;
        bClockBrdT = bBrdT;

        if (snap) {
            wClockFill = wClockFillT;
            wClockText = wClockTextT;
            wClockBrd = wClockBrdT;
            bClockFill = bClockFillT;
            bClockText = bClockTextT;
            bClockBrd = bClockBrdT;
            redrawClockRoundRect(whiteBg, clockBarW, CLOCK_BAR_H, wClockFill, wClockBrd);
            redrawClockRoundRect(blackBg, clockBarW, CLOCK_BAR_H, bClockFill, bClockBrd);
            applyClockTextColors();
        }
    }

    function applyClockTextColors():Void {
        if (whiteTf != null) {
            whiteTf.textColor = wClockText;
            var wf = whiteTf.defaultTextFormat;
            wf.color = wClockText;
            whiteTf.defaultTextFormat = wf;
        }
        if (blackTf != null) {
            blackTf.textColor = bClockText;
            var bf = blackTf.defaultTextFormat;
            bf.color = bClockText;
            blackTf.defaultTextFormat = bf;
        }
    }
}

typedef ClockVisualStyle = {
    var gameTab:Bool;
    var initialMs:Int;
    var clocksStarted:Bool;
    var browsingHistory:Bool;
    var terminal:Bool;
    var timeoutActive:Bool;
    var turnW:Bool;
};
