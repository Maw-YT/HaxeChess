package ui;

import openfl.display.Sprite;
import openfl.display.Shape;
import openfl.display.DisplayObject;
import openfl.events.MouseEvent;
import openfl.events.Event;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import openfl.text.TextField;
import openfl.text.TextFormat;

/**
 * Single-select dropdown; list opens on the stage and stays within the stage bounds.
 */
class UIDropdown extends Sprite {
    public var onChange:String->Void;

    var itemIds:Array<String> = [];
    var itemLabels:Array<String> = [];
    var selectedId:String = "";
    var _width:Int;
    var _rowH:Int;
    var headerBtn:UIButton;
    var labelField:TextField;
    var chevronTf:TextField;
    var listOverlay:Sprite;
    var listContent:Sprite;
    var open:Bool = false;
    var wheelHandler:MouseEvent->Void;

    public function new(w:Int, rowH:Int = 26) {
        super();
        _width = w;
        _rowH = rowH;

        headerBtn = new UIButton(w, rowH, "", 0x333333, 0x505050);
        headerBtn.setOnClick(function() {
            if (open)
                closeList();
            else
                openList();
        });
        addChild(headerBtn);

        labelField = new TextField();
        labelField.defaultTextFormat = new TextFormat("Arial", 11, 0xEEEEEE);
        labelField.selectable = false;
        labelField.mouseEnabled = false;
        labelField.width = w - 28;
        labelField.height = rowH + 4;
        labelField.x = 8;
        labelField.y = (rowH - 14) / 2;
        addChild(labelField);

        chevronTf = new TextField();
        chevronTf.defaultTextFormat = new TextFormat("Arial", 10, 0xFFFFFF);
        chevronTf.text = "▼";
        chevronTf.selectable = false;
        chevronTf.mouseEnabled = false;
        chevronTf.width = 20;
        chevronTf.height = 18;
        chevronTf.x = w - 22;
        chevronTf.y = (rowH - 14) / 2;
        addChild(chevronTf);

        listOverlay = new Sprite();
        listOverlay.visible = false;

        addEventListener(Event.REMOVED_FROM_STAGE, onRemoved);
    }

    function onRemoved(_:Event):Void {
        closeList();
    }

    public function setDropdownWidth(w:Int):Void {
        if (w < 40)
            w = 40;
        _width = w;
        headerBtn.setButtonSize(w, _rowH);
        labelField.width = w - 28;
        labelField.y = (_rowH - 14) / 2;
        chevronTf.x = w - 22;
        chevronTf.y = (_rowH - 14) / 2;
    }

    public function setItems(ids:Array<String>, labels:Array<String>, currentId:String):Void {
        itemIds = ids.copy();
        itemLabels = labels.copy();
        selectedId = currentId;
        refreshLabel();
    }

    public function setSelectedId(id:String):Void {
        selectedId = id;
        refreshLabel();
    }

    function refreshLabel():Void {
        var lab = "";
        for (i in 0...itemIds.length) {
            if (itemIds[i] == selectedId) {
                lab = itemLabels[i];
                break;
            }
        }
        if (lab == "" && itemLabels.length > 0)
            lab = itemLabels[0];
        labelField.text = lab;
    }

    function openList():Void {
        if (itemIds.length == 0 || stage == null)
            return;
        open = true;

        while (listOverlay.numChildren > 0)
            listOverlay.removeChildAt(listOverlay.numChildren - 1);
        if (wheelHandler != null) {
            listOverlay.removeEventListener(MouseEvent.MOUSE_WHEEL, wheelHandler);
            wheelHandler = null;
        }

        listContent = new Sprite();
        var bg = new Shape();
        var listH = itemIds.length * _rowH + 4;
        bg.graphics.beginFill(0x2A2A2A);
        bg.graphics.lineStyle(1, 0x555555);
        bg.graphics.drawRoundRect(0, 0, _width, listH, 4, 4);
        bg.graphics.endFill();
        listContent.addChild(bg);

        var y0 = 2.0;
        for (i in 0...itemIds.length) {
            var id = itemIds[i];
            var lab = itemLabels[i];
            var row = new UIButton(_width - 8, _rowH - 2, lab, 0x3A3A3A, 0x555555);
            row.x = 4;
            row.y = y0;
            y0 += _rowH;
            var captured = id;
            row.setOnClick(function() {
                selectById(captured);
                closeList();
            });
            listContent.addChild(row);
        }

        listOverlay.addChild(listContent);

        var margin = 6.0;
        var sw = stage.stageWidth;
        var sh = stage.stageHeight;
        var gpBelow = localToGlobal(new Point(0, _rowH + 2));
        var gpTop = localToGlobal(new Point(0, 0));
        var availH = sh - margin * 2;

        var lx = Math.max(margin, Math.min(gpBelow.x, sw - _width - margin));

        var visibleH = Math.min(listH, availH);

        var lyBelow = gpBelow.y;
        var lyAbove = gpTop.y - visibleH - 2;
        var ly = lyBelow;
        if (lyBelow + visibleH > sh - margin) {
            if (lyAbove >= margin && lyAbove + visibleH <= sh - margin)
                ly = lyAbove;
            else
                ly = Math.max(margin, Math.min(lyBelow, sh - margin - visibleH));
        }
        ly = Math.max(margin, Math.min(ly, sh - margin - visibleH));

        listOverlay.x = lx;
        listOverlay.y = ly;

        if (listH > visibleH) {
            listContent.y = 0;
            listOverlay.scrollRect = new Rectangle(0, 0, _width, visibleH);
            wheelHandler = function(e:MouseEvent):Void {
                if (!open || listContent == null)
                    return;
                var innerH = itemIds.length * _rowH + 4;
                var vh = listOverlay.scrollRect != null ? listOverlay.scrollRect.height : visibleH;
                if (innerH <= vh)
                    return;
                var dy = e.delta * 18;
                var minY = -(innerH - vh);
                listContent.y = Math.max(minY, Math.min(0, listContent.y - dy));
                e.stopPropagation();
            };
            listOverlay.addEventListener(MouseEvent.MOUSE_WHEEL, wheelHandler, false, 0, true);
        } else {
            listOverlay.scrollRect = null;
        }

        stage.addChild(listOverlay);
        listOverlay.visible = true;
        stage.addEventListener(MouseEvent.MOUSE_DOWN, onStageMouseDown, false, 0, true);
    }

    function onStageMouseDown(e:MouseEvent):Void {
        if (!open)
            return;
        var o:DisplayObject = cast e.target;
        while (o != null) {
            if (o == this || o == listOverlay)
                return;
            o = o.parent;
        }
        closeList();
    }

    function closeList():Void {
        open = false;
        if (wheelHandler != null && listOverlay != null) {
            listOverlay.removeEventListener(MouseEvent.MOUSE_WHEEL, wheelHandler);
            wheelHandler = null;
        }
        listOverlay.scrollRect = null;
        listContent = null;
        if (listOverlay.parent != null)
            listOverlay.parent.removeChild(listOverlay);
        listOverlay.visible = false;
        if (stage != null)
            stage.removeEventListener(MouseEvent.MOUSE_DOWN, onStageMouseDown, false);
    }

    function selectById(id:String):Void {
        selectedId = id;
        refreshLabel();
        if (onChange != null)
            onChange(id);
    }

    public function getSelectedId():String {
        return selectedId;
    }
}
