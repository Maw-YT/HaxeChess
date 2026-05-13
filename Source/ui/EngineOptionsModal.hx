package ui;

import StringTools;
import config.SettingsConfig;
import managers.UCIManager;
import managers.UciEngineOption;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.MouseEvent;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import openfl.text.TextField;
import openfl.text.TextFormat;

private typedef OptRow = {
    var opt:UciEngineOption;
    var tf:UITextField;
    var dd:UIDropdown;
};

/**
 * Modal listing all UCI options reported by the connected engine for the active profile.
 */
class EngineOptionsModal extends Sprite {
    var backdrop:Sprite;
    var panel:Sprite;
    var scrollClip:Sprite;
    var scrollLayer:Sprite;
    var profileId:String;
    var rows:Array<OptRow> = [];
    var scrollY:Float = 0;
    var viewportH:Float = 360;
    var contentH:Float = 0;
    var panelW:Int = 520;
    var onClose:Void->Void;

    public function new() {
        super();
        mouseEnabled = true;
    }

    public function open(
        stageW:Int,
        stageH:Int,
        pid:String,
        uci:UCIManager,
        closeCallback:Void->Void
    ):Void {
        while (numChildren > 0)
            removeChildAt(numChildren - 1);
        rows = [];
        profileId = pid;
        onClose = closeCallback;
        scrollY = 0;

        backdrop = new Sprite();
        backdrop.graphics.beginFill(0x000000, 0.55);
        backdrop.graphics.drawRect(0, 0, stageW, stageH);
        backdrop.graphics.endFill();
        backdrop.mouseEnabled = true;
        backdrop.addEventListener(MouseEvent.CLICK, function(e:MouseEvent) {
            if (e.target == backdrop)
                doClose();
        });
        addChild(backdrop);

        panelW = Std.int(Math.min(540, stageW - 48));
        var ph = Std.int(Math.min(480, stageH - 48));
        viewportH = ph - 110;
        panel = new Sprite();
        panel.x = (stageW - panelW) * 0.5;
        panel.y = (stageH - ph) * 0.5;
        var bg = new Shape();
        bg.graphics.beginFill(0x242424);
        bg.graphics.lineStyle(1, 0x555555);
        bg.graphics.drawRoundRect(0, 0, panelW, ph, 8, 8);
        bg.graphics.endFill();
        panel.addChild(bg);
        addChild(panel);

        var title = new TextField();
        title.selectable = false;
        title.defaultTextFormat = new TextFormat("Arial", 16, 0xFFFFFF, true);
        title.text = "Engine UCI options";
        title.width = panelW - 20;
        title.height = 28;
        title.x = 14;
        title.y = 10;
        panel.addChild(title);

        scrollClip = new Sprite();
        scrollClip.x = 10;
        scrollClip.y = 44;
        scrollClip.scrollRect = new Rectangle(0, 0, panelW - 20, viewportH);
        panel.addChild(scrollClip);

        scrollLayer = new Sprite();
        scrollLayer.y = 0;
        scrollClip.addChild(scrollLayer);

        var opts = uci.getEngineOptions();
        var y:Float = 0;
        var small = new TextFormat("Arial", 11, 0xAAAAAA);
        var labelFmt = new TextFormat("Arial", 12, 0xDDDDDD, true);

        for (opt in opts) {
            var saved = SettingsConfig.getOptionOverride(profileId, opt.name);
            var startVal = saved != null ? saved : opt.defaultValue;

            var lab = new TextField();
            lab.selectable = false;
            lab.defaultTextFormat = labelFmt;
            lab.text = opt.name + "  (" + opt.type + ")";
            lab.width = panelW - 40;
            lab.height = 22;
            lab.x = 0;
            lab.y = y;
            scrollLayer.addChild(lab);
            y += 24;

            var row:OptRow = {opt: opt, tf: null, dd: null};

            switch (opt.type) {
                case "check":
                    var tf = new UITextField(120, 26, "");
                    tf.x = 0;
                    tf.y = y;
                    tf.setText(startVal == "true" || startVal == "1" ? "true" : "false");
                    scrollLayer.addChild(tf);
                    row.tf = tf;
                    var hint = new TextField();
                    hint.selectable = false;
                    hint.defaultTextFormat = small;
                    hint.text = "Type true or false";
                    hint.width = 200;
                    hint.height = 18;
                    hint.x = 130;
                    hint.y = y + 4;
                    scrollLayer.addChild(hint);
                case "spin":
                    var tf2 = new UITextField(100, 26, "");
                    tf2.x = 0;
                    tf2.y = y;
                    tf2.setText(startVal != "" ? startVal : opt.defaultValue);
                    scrollLayer.addChild(tf2);
                    row.tf = tf2;
                    var h2 = new TextField();
                    h2.selectable = false;
                    h2.defaultTextFormat = small;
                    h2.text = "min " + opt.min + "  max " + opt.max + "  default " + opt.defaultValue;
                    h2.width = panelW - 40;
                    h2.height = 18;
                    h2.x = 110;
                    h2.y = y + 4;
                    scrollLayer.addChild(h2);
                case "combo":
                    var dd = new UIDropdown(Std.int(Math.min(400, panelW - 40)), 26);
                    dd.x = 0;
                    dd.y = y;
                    var ids = opt.comboValues.copy();
                    var labels = opt.comboValues.copy();
                    var cur = startVal != "" ? startVal : opt.defaultValue;
                    if (ids.length == 0) {
                        ids = [cur];
                        labels = [cur];
                    }
                    dd.setItems(ids, labels, cur);
                    scrollLayer.addChild(dd);
                    row.dd = dd;
                case "string":
                    var tf3 = new UITextField(Std.int(Math.min(420, panelW - 40)), 26, "");
                    tf3.x = 0;
                    tf3.y = y;
                    tf3.setText(startVal);
                    scrollLayer.addChild(tf3);
                    row.tf = tf3;
                case "button":
                    var b = new UIButton(200, 28, "Run: " + opt.name, 0x37474F, 0x546E7A);
                    b.x = 0;
                    b.y = y;
                    b.setOnClick(function() uci.triggerOptionButton(opt.name));
                    scrollLayer.addChild(b);
                default:
                    var skip = new TextField();
                    skip.selectable = false;
                    skip.defaultTextFormat = small;
                    skip.text = "(unsupported type " + opt.type + ")";
                    skip.width = panelW - 40;
                    skip.height = 18;
                    skip.x = 0;
                    skip.y = y;
                    scrollLayer.addChild(skip);
            }
            if (row.tf != null || row.dd != null)
                rows.push(row);
            y += 36;
        }

        contentH = y + 8;
        scrollLayer.y = 0;

        var closeBtn = new UIButton(100, 30, "Close", 0x444444, 0x666666);
        closeBtn.x = panelW - 220;
        closeBtn.y = ph - 44;
        closeBtn.setOnClick(function() doClose());
        panel.addChild(closeBtn);

        var applyBtn = new UIButton(100, 30, "Apply", 0x2E7D32, 0x4CAF50);
        applyBtn.x = panelW - 110;
        applyBtn.y = ph - 44;
        applyBtn.setOnClick(function() onApply(uci));
        panel.addChild(applyBtn);

        addEventListener(Event.ADDED_TO_STAGE, onAdded, false, 0, true);
    }

    function onAdded(_:Event):Void {
        removeEventListener(Event.ADDED_TO_STAGE, onAdded);
        if (stage != null)
            stage.addEventListener(MouseEvent.MOUSE_WHEEL, onWheel, true, 0, true);
    }

    function onWheel(e:MouseEvent):Void {
        if (scrollClip == null || scrollLayer == null)
            return;
        var gp = scrollClip.localToGlobal(new Point(0, 0));
        if (stage.mouseX < gp.x || stage.mouseX > gp.x + panelW - 20
            || stage.mouseY < gp.y || stage.mouseY > gp.y + viewportH)
            return;
        var maxS = Math.max(0, contentH - viewportH);
        if (maxS <= 0)
            return;
        scrollY = Math.max(0, Math.min(maxS, scrollY - e.delta * 28));
        scrollLayer.y = -scrollY;
        e.stopPropagation();
    }

    function onApply(uci:UCIManager):Void {
        for (r in rows) {
            var o = r.opt;
            var val:String = "";
            if (r.dd != null)
                val = r.dd.getSelectedId();
            else if (r.tf != null)
                val = StringTools.trim(r.tf.getText());
            if (o.type == "check") {
                var t = val.toLowerCase();
                if (t != "true" && t != "false")
                    continue;
            }
            if (val != "")
                SettingsConfig.setOptionOverride(profileId, o.name, val);
        }
        SettingsConfig.save();
        if (uci.isEngineReady()) {
            var m = SettingsConfig.getMergedOptionMap();
            for (n => v in m) {
                var t = StringTools.trim(v);
                if (t != "")
                    uci.setOption(n, t);
            }
        }
        doClose();
    }

    function doClose():Void {
        if (stage != null)
            stage.removeEventListener(MouseEvent.MOUSE_WHEEL, onWheel, true);
        if (parent != null)
            parent.removeChild(this);
        if (onClose != null)
            onClose();
    }
}
