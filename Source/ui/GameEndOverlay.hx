package ui;

import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.MouseEvent;
import openfl.geom.Rectangle;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.text.TextFormatAlign;

private typedef ConfettiBit = {
    var x:Float;
    var y:Float;
    var vx:Float;
    var vy:Float;
    var ay:Float;
    var rot:Float;
    var vr:Float;
    var col:Int;
    var w:Float;
    var h:Float;
};

/**
 * Board-sized dim + headline for game outcome. Optional confetti (checkmate).
 * Click anywhere to dismiss (caller clears dismissed state on new game).
 */
class GameEndOverlay extends Sprite {
    var dim:Sprite;
    var clickCatcher:Sprite;
    var panel:Sprite;
    var titleTf:TextField;
    var subTf:TextField;
    var confettiLayer:Shape;
    var confettiOn:Bool = false;
    var bits:Array<ConfettiBit>;
    var cw:Int = 800;
    var ch:Int = 600;

    public var onDismissRequest:Void->Void;

    public function new() {
        super();
        visible = false;
        mouseEnabled = true;
        mouseChildren = true;

        dim = new Sprite();
        dim.mouseEnabled = false;
        dim.mouseChildren = false;
        dim.graphics.beginFill(0x000000, 0.62);
        dim.graphics.drawRect(0, 0, 100, 100);
        dim.graphics.endFill();
        addChild(dim);

        clickCatcher = new Sprite();
        clickCatcher.graphics.beginFill(0x000000, 0);
        clickCatcher.graphics.drawRect(0, 0, 100, 100);
        clickCatcher.graphics.endFill();
        clickCatcher.mouseEnabled = true;
        clickCatcher.addEventListener(MouseEvent.CLICK, onHitClick);

        confettiLayer = new Shape();
        addChild(confettiLayer);

        panel = new Sprite();
        panel.mouseEnabled = false;
        panel.mouseChildren = false;
        addChild(panel);

        titleTf = new TextField();
        titleTf.selectable = false;
        titleTf.mouseEnabled = false;
        titleTf.multiline = true;
        titleTf.wordWrap = true;
        titleTf.embedFonts = false;
        panel.addChild(titleTf);

        subTf = new TextField();
        subTf.selectable = false;
        subTf.mouseEnabled = false;
        subTf.multiline = true;
        subTf.wordWrap = true;
        subTf.embedFonts = false;
        panel.addChild(subTf);

        addChild(clickCatcher);

        bits = [];
    }

    function onHitClick(_:MouseEvent):Void {
        dismiss();
        if (onDismissRequest != null)
            onDismissRequest();
    }

    public function dismiss():Void {
        removeEventListener(Event.ENTER_FRAME, onConfettiFrame);
        confettiOn = false;
        bits.resize(0);
        confettiLayer.graphics.clear();
        visible = false;
    }

    public function layout(w:Int, h:Int):Void {
        cw = w < 1 ? 1 : w;
        ch = h < 1 ? 1 : h;
        dim.graphics.clear();
        dim.graphics.beginFill(0x000000, 0.62);
        dim.graphics.drawRect(0, 0, cw, ch);
        dim.graphics.endFill();
        clickCatcher.graphics.clear();
        clickCatcher.graphics.beginFill(0x000000, 0);
        clickCatcher.graphics.drawRect(0, 0, cw, ch);
        clickCatcher.graphics.endFill();
        scrollRect = new Rectangle(0, 0, cw, ch);
        positionText();
    }

    function positionText():Void {
        var margin = Std.int(Math.max(8, Math.min(32, cw * 0.06)));
        var pw = Std.int(Math.max(40, cw - margin * 2));
        titleTf.width = pw;
        titleTf.x = (cw - pw) * 0.5;
        titleTf.y = ch * 0.32;
        subTf.width = pw;
        subTf.x = titleTf.x;
        subTf.y = titleTf.y + titleTf.textHeight + 12;
    }

    /**
     * Show overlay. If `useConfetti`, spawns light confetti until dismissed.
     */
    public function reveal(w:Int, h:Int, title:String, subtitle:String, useConfetti:Bool):Void {
        layout(w, h);
        var titlePt = Std.int(Math.max(14, Math.min(32, w * 0.09)));
        var subPt = Std.int(Math.max(11, Math.min(18, w * 0.052)));
        var tfTitle = new TextFormat("_sans", titlePt, 0xFFFFFF, true);
        tfTitle.align = TextFormatAlign.CENTER;
        titleTf.defaultTextFormat = tfTitle;
        titleTf.text = title;
        titleTf.setTextFormat(tfTitle);

        var tfSub = new TextFormat("_sans", subPt, 0xD0D0D0, false);
        tfSub.align = TextFormatAlign.CENTER;
        subTf.defaultTextFormat = tfSub;
        subTf.text = subtitle != null && subtitle != "" ? subtitle : "";
        subTf.setTextFormat(tfSub);

        positionText();

        confettiOn = useConfetti;
        bits.resize(0);
        confettiLayer.graphics.clear();
        if (confettiOn) {
            var n = Std.int(Math.max(32, Math.min(72, (cw * ch) / 900)));
            var cols = [0xFF6B6B, 0xFFD93D, 0x6BCB77, 0x4D96FF, 0xC084FC, 0xFF8FAB];
            for (i in 0...n) {
                bits.push({
                    x: Math.random() * cw,
                    y: -40 - Math.random() * 200,
                    vx: (Math.random() - 0.5) * 3.2,
                    vy: 1.5 + Math.random() * 4.5,
                    ay: 0.12 + Math.random() * 0.08,
                    rot: Math.random() * 6.28,
                    vr: (Math.random() - 0.5) * 0.18,
                    col: cols[Std.int(Math.random() * cols.length)],
                    w: 6 + Math.random() * 8,
                    h: 4 + Math.random() * 7,
                });
            }
            addEventListener(Event.ENTER_FRAME, onConfettiFrame);
        } else {
            removeEventListener(Event.ENTER_FRAME, onConfettiFrame);
        }

        visible = true;
    }

    function onConfettiFrame(_:Event):Void {
        if (!confettiOn || !visible)
            return;
        var g = confettiLayer.graphics;
        g.clear();
        for (b in bits) {
            b.vy += b.ay;
            b.x += b.vx;
            b.y += b.vy;
            b.rot += b.vr;
            if (b.y > ch + 40) {
                b.y = -30 - Math.random() * 120;
                b.x = Math.random() * cw;
                b.vy = 1.5 + Math.random() * 4;
            }
            g.lineStyle(0, 0, 0);
            g.beginFill(b.col, 0.92);
            g.drawRect(b.x, b.y, b.w, b.h);
            g.endFill();
        }
    }
}
