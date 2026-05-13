package ui;

import StringTools;
import openfl.display.DisplayObject;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.MouseEvent;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import openfl.text.TextField;
import openfl.text.TextFormat;
import config.SettingsConfig;
import config.BoardLayout;

/**
 * Settings tab: gameplay, board, display. UCI engines are on the Engines tab.
 */
class SettingsTab extends Sprite {
    var depthInput:UITextField;
    var timeInput:UITextField;
    var playAsSummary:TextField;

    var btnPlayWhite:UIButton;
    var btnPlayBlack:UIButton;
    var btnPlayBoth:UIButton;

    var illegalSummary:TextField;

    var contentW:Int;
    var viewportH:Int;
    var innerW:Int;
    var scrollBarW:Int = 12;
    var scrollLayer:Sprite;
    var scrollClip:Sprite;
    var scrollTrack:Sprite;
    var scrollThumb:Sprite;
    var contentH:Float = 400;
    var scrollY:Float = 0;
    var thumbDragging:Bool = false;
    var thumbDragThumbOffsetY:Float = 0;

    /** Wired from Main: reset board to starting position and refresh UI. */
    public var onResetBoard:Void->Void;

    /** After changing layout preset: apply layout and refresh game + engine. */
    public var onBoardLayoutApply:Void->Void;
    /** After changing time control preset. */
    public var onTimeControlChanged:Void->Void;

    /** After toggling full screen from Settings (apply `SettingsConfig.windowFullscreen` to the window). */
    public var onFullscreenModeChange:Void->Void;

    var fullscreenSummary:TextField;

    var layoutDropdown:UIDropdown;
    var timeControlDropdown:UIDropdown;
    var clockIncrementInput:UITextField;

    public function new(contentWidth:Int, viewportHeight:Int) {
        super();
        this.contentW = contentWidth;
        this.viewportH = viewportHeight;
        build();
    }

    function build():Void {
        innerW = contentW - scrollBarW - 6;

        scrollClip = new Sprite();
        scrollClip.scrollRect = new Rectangle(0, 0, innerW, viewportH);
        scrollLayer = new Sprite();
        scrollClip.addChild(scrollLayer);
        addChild(scrollClip);

        scrollTrack = new Sprite();
        scrollTrack.x = innerW + 4;
        scrollTrack.y = 0;
        addChild(scrollTrack);

        scrollThumb = new Sprite();
        scrollThumb.x = innerW + 4;
        scrollThumb.y = 0;
        scrollThumb.buttonMode = true;
        addChild(scrollThumb);

        scrollTrack.addEventListener(MouseEvent.MOUSE_DOWN, onTrackMouseDown);
        scrollThumb.addEventListener(MouseEvent.MOUSE_DOWN, onThumbMouseDown);
        addEventListener(Event.ADDED_TO_STAGE, onAddedToStage, false, 0, true);
        addEventListener(Event.REMOVED_FROM_STAGE, onRemovedFromStage, false, 0, true);

        var yPos = 10;
        var labelFmt = new TextFormat("Arial", 14, 0xFFFFFF, true);
        var smallFmt = new TextFormat("Arial", 11, 0xAAAAAA);

        addLabel("Settings", labelFmt, 18, 10, yPos, 200, 30);
        yPos += 40;

        addLabel("Configure UCI engines, paths, and engine options on the Engines tab.", smallFmt, 11, 10, yPos, innerW - 10, 36);
        yPos += 44;

        addLabel("Search (used when the engine thinks)", labelFmt, 14, 10, yPos, 340, 25);
        yPos += 28;

        addLabel("Depth (plies)", smallFmt, 11, 10, yPos, 100, 20);
        depthInput = new UITextField(70, 26, "");
        depthInput.x = 115;
        depthInput.y = yPos - 2;
        depthInput.setText(Std.string(SettingsConfig.engineDepth));
        depthInput.addEventListener(Event.CHANGE, onDepthTimeChange);
        scrollLayer.addChild(depthInput);

        addLabel("Move time (ms, 0 = depth only)", smallFmt, 11, 200, yPos, 200, 20);
        timeInput = new UITextField(90, 26, "");
        timeInput.x = 400;
        timeInput.y = yPos - 2;
        timeInput.setText(Std.string(SettingsConfig.engineTimeMs));
        timeInput.addEventListener(Event.CHANGE, onDepthTimeChange);
        scrollLayer.addChild(timeInput);
        yPos += 38;

        addLabel("Engine plays as", labelFmt, 14, 10, yPos, 200, 25);
        yPos += 28;

        btnPlayWhite = new UIButton(72, 26, "White", 0x444444, 0x666666);
        btnPlayWhite.x = 10;
        btnPlayWhite.y = yPos;
        btnPlayWhite.setOnClick(function() setEnginePlayAs("white"));
        scrollLayer.addChild(btnPlayWhite);

        btnPlayBlack = new UIButton(72, 26, "Black", 0x444444, 0x666666);
        btnPlayBlack.x = 92;
        btnPlayBlack.y = yPos;
        btnPlayBlack.setOnClick(function() setEnginePlayAs("black"));
        scrollLayer.addChild(btnPlayBlack);

        btnPlayBoth = new UIButton(72, 26, "Both", 0x444444, 0x666666);
        btnPlayBoth.x = 174;
        btnPlayBoth.y = yPos;
        btnPlayBoth.setOnClick(function() setEnginePlayAs("both"));
        scrollLayer.addChild(btnPlayBoth);
        yPos += 34;

        playAsSummary = addLabel("Current: " + SettingsConfig.enginePlayAs, smallFmt, 11, 10, yPos, innerW - 10, 20);
        yPos += 36;

        addLabel("Gameplay", labelFmt, 14, 10, yPos, 200, 25);
        yPos += 28;
        addLabel("Timed mode", smallFmt, 11, 10, yPos, 120, 20);
        timeControlDropdown = new UIDropdown(200, 28);
        timeControlDropdown.x = 120;
        timeControlDropdown.y = yPos - 4;
        timeControlDropdown.setItems(
            ["none", "rapid", "blitz", "bullet"],
            ["None (untimed)", "Rapid (10:00)", "Blitz (3:00)", "Bullet (1:00)"],
            SettingsConfig.timeControlPreset
        );
        timeControlDropdown.onChange = onTimeControlDropdownChange;
        scrollLayer.addChild(timeControlDropdown);
        yPos += 36;
        addLabel(
            "Increment (seconds per move) — added to your clock after each move you play (0 = none).",
            smallFmt, 11, 10, yPos, innerW - 10, 36
        );
        yPos += 40;
        clockIncrementInput = new UITextField(80, 28, "");
        clockIncrementInput.x = 10;
        clockIncrementInput.y = yPos;
        clockIncrementInput.setText(Std.string(SettingsConfig.clockIncrementSeconds));
        clockIncrementInput.addEventListener(Event.CHANGE, onClockIncrementChange);
        scrollLayer.addChild(clockIncrementInput);
        yPos += 36;
        addLabel(
            "Allow illegal moves — you can still see legal-move hints (dots). Useful for LLM vs LLM or custom setups.",
            smallFmt, 11, 10, yPos, innerW - 10, 44
        );
        yPos += 48;
        illegalSummary = addLabel("", smallFmt, 11, 10, yPos, innerW - 10, 20);
        yPos += 24;
        var ilOn = new UIButton(80, 28, "Illegal: ON", 0x5D4037, 0x8D6E63);
        ilOn.x = 10;
        ilOn.y = yPos;
        ilOn.setOnClick(function() setAllowIllegal(true));
        scrollLayer.addChild(ilOn);
        var ilOff = new UIButton(80, 28, "Illegal: OFF", 0x37474F, 0x546E7A);
        ilOff.x = 100;
        ilOff.y = yPos;
        ilOff.setOnClick(function() setAllowIllegal(false));
        scrollLayer.addChild(ilOff);
        yPos += 36;

        addLabel("Display", labelFmt, 14, 10, yPos, 200, 25);
        yPos += 28;
        addLabel("Full screen uses the whole monitor. Press F11 anytime to toggle.", smallFmt, 11, 10, yPos, innerW - 10, 36);
        yPos += 40;
        fullscreenSummary = addLabel("", smallFmt, 11, 10, yPos, innerW - 10, 20);
        yPos += 26;
        var fsOn = new UIButton(120, 28, "Full screen", 0x1B5E20, 0x43A047);
        fsOn.x = 10;
        fsOn.y = yPos;
        fsOn.setOnClick(function() setWindowFullscreenMode(true));
        scrollLayer.addChild(fsOn);
        var fsOff = new UIButton(120, 28, "Windowed", 0x37474F, 0x546E7A);
        fsOff.x = 140;
        fsOff.y = yPos;
        fsOff.setOnClick(function() setWindowFullscreenMode(false));
        scrollLayer.addChild(fsOff);
        yPos += 36;
        refreshFullscreenSummary();

        addLabel("Board", labelFmt, 14, 10, yPos, 200, 25);
        yPos += 28;
        addLabel(
            "Starting layout — choosing a preset reloads the board from that position and clears move history.",
            smallFmt, 11, 10, yPos, innerW - 10, 40
        );
        yPos += 44;
        var choices = BoardLayout.layoutChoices();
        var ids = [for (c in choices) c.id];
        var labels = [for (c in choices) c.label];
        layoutDropdown = new UIDropdown(Std.int(Math.min(420, innerW - 20)), 28);
        layoutDropdown.x = 10;
        layoutDropdown.y = yPos;
        layoutDropdown.setItems(ids, labels, SettingsConfig.boardLayoutId);
        layoutDropdown.onChange = onLayoutDropdownChange;
        scrollLayer.addChild(layoutDropdown);
        yPos += 36;

        addLabel(
            "Reset the board to the current layout’s start, clear move history, and sync the engine if connected.",
            smallFmt, 11, 10, yPos, innerW - 10, 40
        );
        yPos += 44;
        var resetBtn = new UIButton(140, 30, "Reset board", 0x37474F, 0x546E7A);
        resetBtn.x = 10;
        resetBtn.y = yPos;
        resetBtn.setOnClick(function() {
            if (onResetBoard != null)
                onResetBoard();
        });
        scrollLayer.addChild(resetBtn);
        yPos += 40;

        contentH = yPos + 16;
        scrollY = 0;
        scrollLayer.y = 0;

        /* hitTestPoint only registers pixels with drawable hits; empty/clipped gaps would miss the wheel. */
        var scrollHitFill = new Sprite();
        scrollHitFill.graphics.beginFill(0x000000, 0.01);
        scrollHitFill.graphics.drawRect(0, 0, innerW, contentH);
        scrollHitFill.graphics.endFill();
        scrollLayer.addChildAt(scrollHitFill, 0);

        redrawScrollChrome();
    }

    function onAddedToStage(_:Event):Void {
        if (stage != null)
            stage.addEventListener(MouseEvent.MOUSE_WHEEL, onStageWheelCapture, true, 0x7FFFFFFF);
    }

    function onRemovedFromStage(_:Event):Void {
        if (stage != null)
            stage.removeEventListener(MouseEvent.MOUSE_WHEEL, onStageWheelCapture, true);
    }

    function maxScroll():Float {
        return Math.max(0, contentH - viewportH);
    }

    function scrollBy(delta:Float):Void {
        var mx = maxScroll();
        scrollY = Math.max(0, Math.min(mx, scrollY + delta));
        scrollLayer.y = -scrollY;
        redrawScrollChrome();
    }

    function displayChainVisible():Bool {
        var o:DisplayObject = this;
        while (o != null) {
            if (!o.visible)
                return false;
            o = o.parent;
        }
        return true;
    }

    /** Full tab rectangle in stage space — not tied to per-pixel hit targets (avoids holes when scrolled). */
    function pointerInTabRect(stageX:Float, stageY:Float):Bool {
        var tl = localToGlobal(new Point(0, 0));
        var br = localToGlobal(new Point(contentW, viewportH));
        var minX = Math.min(tl.x, br.x);
        var maxX = Math.max(tl.x, br.x);
        var minY = Math.min(tl.y, br.y);
        var maxY = Math.max(tl.y, br.y);
        return stageX >= minX && stageX <= maxX && stageY >= minY && stageY <= maxY;
    }

    /**
     * Stage capture + high priority: TextFields and Lime often consume MOUSE_WHEEL before it bubbles here.
     */
    function onStageWheelCapture(e:MouseEvent):Void {
        if (stage == null)
            return;
        if (!displayChainVisible())
            return;
        if (!pointerInTabRect(stage.mouseX, stage.mouseY))
            return;

        var dy = e.delta;
        if (dy == 0)
            return;

        if (maxScroll() <= 0)
            return;
        scrollBy(-dy * 36);
        e.stopImmediatePropagation();
    }

    function thumbMetrics():{thumbH:Float, travel:Float} {
        var trackH = viewportH;
        var thumbH = Math.max(28, trackH * (viewportH / contentH));
        thumbH = Math.min(thumbH, trackH);
        var travel = Math.max(1, trackH - thumbH);
        return {thumbH: thumbH, travel: travel};
    }

    function thumbTopY():Float {
        var mx = maxScroll();
        var m = thumbMetrics();
        return (mx > 0) ? (scrollY / mx) * m.travel : 0;
    }

    function onTrackMouseDown(e:MouseEvent):Void {
        if (maxScroll() <= 0)
            return;
        var local = scrollTrack.globalToLocal(new Point(e.stageX, e.stageY));
        var m = thumbMetrics();
        var ty = thumbTopY();
        if (local.y >= ty && local.y <= ty + m.thumbH)
            return;
        var ratio = Math.max(0, Math.min(1, (local.y - m.thumbH * 0.5) / m.travel));
        var mx = maxScroll();
        scrollY = Math.max(0, Math.min(mx, ratio * mx));
        scrollLayer.y = -scrollY;
        redrawScrollChrome();
    }

    function onThumbMouseDown(e:MouseEvent):Void {
        if (maxScroll() <= 0)
            return;
        e.stopImmediatePropagation();
        thumbDragging = true;
        var local = scrollTrack.globalToLocal(new Point(e.stageX, e.stageY));
        thumbDragThumbOffsetY = local.y - thumbTopY();
        stage.addEventListener(MouseEvent.MOUSE_MOVE, onThumbMouseMove);
        stage.addEventListener(MouseEvent.MOUSE_UP, onThumbMouseUp);
    }

    function redrawScrollChrome():Void {
        var mx = maxScroll();
        var trackH = viewportH;
        var tw = scrollBarW;

        scrollTrack.graphics.clear();
        scrollThumb.graphics.clear();

        if (mx <= 0) {
            scrollTrack.visible = false;
            scrollThumb.visible = false;
            return;
        }
        scrollTrack.visible = true;
        scrollThumb.visible = true;

        scrollTrack.graphics.beginFill(0x2A2A2A);
        scrollTrack.graphics.drawRect(0, 0, tw, trackH);
        scrollTrack.graphics.endFill();

        var thumbH = Math.max(28, trackH * (viewportH / contentH));
        thumbH = Math.min(thumbH, trackH);
        var travel = trackH - thumbH;
        var ty = (mx > 0) ? (scrollY / mx) * travel : 0;

        scrollThumb.graphics.beginFill(0x6A6A6A);
        scrollThumb.graphics.drawRect(0, ty, tw, thumbH);
        scrollThumb.graphics.endFill();
    }

    function onThumbMouseMove(_:MouseEvent):Void {
        if (!thumbDragging)
            return;
        var mx = maxScroll();
        var m = thumbMetrics();
        var local = scrollTrack.globalToLocal(new Point(stage.mouseX, stage.mouseY));
        var thumbTop = local.y - thumbDragThumbOffsetY;
        var ratio = thumbTop / m.travel;
        scrollY = Math.max(0, Math.min(mx, ratio * mx));
        scrollLayer.y = -scrollY;
        redrawScrollChrome();
    }

    function onThumbMouseUp(_:MouseEvent):Void {
        thumbDragging = false;
        stage.removeEventListener(MouseEvent.MOUSE_MOVE, onThumbMouseMove);
        stage.removeEventListener(MouseEvent.MOUSE_UP, onThumbMouseUp);
    }

    function setAllowIllegal(on:Bool):Void {
        SettingsConfig.allowIllegalMoves = on;
        SettingsConfig.save();
        refreshIllegalMovesUI();
    }

    function refreshIllegalMovesUI():Void {
        if (illegalSummary != null) {
            illegalSummary.text = SettingsConfig.allowIllegalMoves
                ? "Illegal moves are allowed (select any piece; hints = legal only)."
                : "Illegal moves are off — standard chess rules.";
        }
    }

    function setWindowFullscreenMode(on:Bool):Void {
        SettingsConfig.windowFullscreen = on;
        SettingsConfig.save();
        refreshFullscreenSummary();
        if (onFullscreenModeChange != null)
            onFullscreenModeChange();
    }

    public function refreshFullscreenSummary():Void {
        if (fullscreenSummary != null) {
            fullscreenSummary.text = SettingsConfig.windowFullscreen
                ? "Mode: full screen (F11 toggles)."
                : "Mode: windowed (F11 toggles).";
        }
    }

    function addLabel(text:String, fmt:TextFormat, size:Int, x:Float, y:Float, w:Float, h:Float):TextField {
        fmt.size = size;
        var tf = new TextField();
        tf.defaultTextFormat = fmt;
        tf.text = text;
        tf.selectable = false;
        tf.width = w;
        tf.height = h;
        tf.x = x;
        tf.y = y;
        scrollLayer.addChild(tf);
        return tf;
    }

    function setEnginePlayAs(side:String):Void {
        SettingsConfig.enginePlayAs = side;
        SettingsConfig.save();
        playAsSummary.text = "Current: " + side;
    }

    function onDepthTimeChange(_:Event):Void {
        var d = Std.parseInt(StringTools.trim(depthInput.getText()));
        if (d != null && d > 0)
            SettingsConfig.engineDepth = d;
        var t = Std.parseInt(StringTools.trim(timeInput.getText()));
        if (t != null && t >= 0)
            SettingsConfig.engineTimeMs = t;
        SettingsConfig.save();
    }

    public function syncInputsFromConfig():Void {
        if (depthInput != null)
            depthInput.setText(Std.string(SettingsConfig.engineDepth));
        if (timeInput != null)
            timeInput.setText(Std.string(SettingsConfig.engineTimeMs));
        if (playAsSummary != null)
            playAsSummary.text = "Current: " + SettingsConfig.enginePlayAs;
        refreshIllegalMovesUI();
        refreshFullscreenSummary();
        if (layoutDropdown != null) {
            var ch = BoardLayout.layoutChoices();
            layoutDropdown.setItems([for (c in ch) c.id], [for (c in ch) c.label], SettingsConfig.boardLayoutId);
        }
        if (timeControlDropdown != null) {
            timeControlDropdown.setItems(
                ["none", "rapid", "blitz", "bullet"],
                ["None (untimed)", "Rapid (10:00)", "Blitz (3:00)", "Bullet (1:00)"],
                SettingsConfig.timeControlPreset
            );
        }
        if (clockIncrementInput != null)
            clockIncrementInput.setText(Std.string(SettingsConfig.clockIncrementSeconds));
    }

    function onLayoutDropdownChange(id:String):Void {
        SettingsConfig.boardLayoutId = id;
        SettingsConfig.save();
        if (onBoardLayoutApply != null)
            onBoardLayoutApply();
    }

    function onTimeControlDropdownChange(id:String):Void {
        SettingsConfig.timeControlPreset = id;
        SettingsConfig.save();
        if (onTimeControlChanged != null)
            onTimeControlChanged();
    }

    function onClockIncrementChange(_:Event):Void {
        var t = StringTools.trim(clockIncrementInput.getText());
        var v = Std.parseInt(t);
        SettingsConfig.clockIncrementSeconds = v != null && v >= 0 ? v : 0;
        if (v == null || v < 0)
            clockIncrementInput.setText(Std.string(SettingsConfig.clockIncrementSeconds));
        SettingsConfig.save();
    }
}
