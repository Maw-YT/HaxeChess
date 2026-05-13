package ui;

import openfl.display.Sprite;
import openfl.events.MouseEvent;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import openfl.Lib;

/**
 * Fixed-size viewport with a pannable/zoomable `world` child (wheel = zoom to cursor, middle-drag or Alt+left-drag = pan).
 */
class BoardViewPort extends Sprite {
    public var world(default, null):Sprite;

    var clipW:Int;
    var clipH:Int;
    var minScale:Float = 0.15;
    var maxScale:Float = 6.0;
    var panning:Bool = false;
    var panLastSX:Float = 0;
    var panLastSY:Float = 0;
    var panUsesMiddle:Bool = false;
    var stagePanMove:MouseEvent->Void;
    var stagePanUp:MouseEvent->Void;

    public function new(w:Int, h:Int) {
        super();
        clipW = w < 1 ? 1 : w;
        clipH = h < 1 ? 1 : h;
        mouseChildren = true;

        graphics.beginFill(0x1E1E22);
        graphics.drawRect(0, 0, clipW, clipH);
        graphics.endFill();

        world = new Sprite();
        addChild(world);

        scrollRect = new Rectangle(0, 0, clipW, clipH);

        addEventListener(MouseEvent.MOUSE_WHEEL, onWheel, false, 0, true);
        addEventListener(MouseEvent.MIDDLE_MOUSE_DOWN, onMiddleDown, false, 0, true);
        addEventListener(MouseEvent.MOUSE_DOWN, onMouseDownMaybePan, false, 0, true);
    }

    public function getClipWidth():Int {
        return clipW;
    }

    public function getClipHeight():Int {
        return clipH;
    }

    public function setClipSize(w:Int, h:Int):Void {
        clipW = w < 1 ? 1 : w;
        clipH = h < 1 ? 1 : h;
        scrollRect = new Rectangle(0, 0, clipW, clipH);
        graphics.clear();
        graphics.beginFill(0x1E1E22);
        graphics.drawRect(0, 0, clipW, clipH);
        graphics.endFill();
    }

    /** Fit entire logical board (unscaled) centered in the viewport at scale 1. */
    public function resetView():Void {
        world.scaleX = world.scaleY = 1;
        centerWorldInClip();
    }

    public function centerWorldInClip():Void {
        var bw = world.width;
        var bh = world.height;
        if (bw <= 0 || bh <= 0) {
            world.x = (clipW - bw) * 0.5;
            world.y = (clipH - bh) * 0.5;
            return;
        }
        world.x = (clipW - bw) * 0.5;
        world.y = (clipH - bh) * 0.5;
    }

    function onWheel(e:MouseEvent):Void {
        var z = e.delta > 0 ? 1.12 : (1.0 / 1.12);
        applyZoomAtStage(e.stageX, e.stageY, z);
        e.stopPropagation();
    }

    public function applyZoomAtStage(stageX:Float, stageY:Float, factor:Float):Void {
        var mouseLocal = globalToLocal(new Point(stageX, stageY));
        var relX = mouseLocal.x - world.x;
        var relY = mouseLocal.y - world.y;
        var wx = relX / world.scaleX;
        var wy = relY / world.scaleY;
        var newS = clampf(world.scaleX * factor, minScale, maxScale);
        world.scaleX = world.scaleY = newS;
        world.x = mouseLocal.x - wx * world.scaleX;
        world.y = mouseLocal.y - wy * world.scaleY;
    }

    function onMiddleDown(e:MouseEvent):Void {
        beginPan(e.stageX, e.stageY, true);
        e.stopPropagation();
    }

    function onMouseDownMaybePan(e:MouseEvent):Void {
        if (!e.altKey)
            return;
        beginPan(e.stageX, e.stageY, false);
        e.stopPropagation();
    }

    function beginPan(sx:Float, sy:Float, middle:Bool):Void {
        if (panning)
            return;
        panning = true;
        panUsesMiddle = middle;
        panLastSX = sx;
        panLastSY = sy;
        var st = Lib.current.stage;
        stagePanMove = function(e2:MouseEvent):Void {
            if (!panning)
                return;
            world.x += e2.stageX - panLastSX;
            world.y += e2.stageY - panLastSY;
            panLastSX = e2.stageX;
            panLastSY = e2.stageY;
        };
        stagePanUp = function(_:MouseEvent):Void {
            endPan();
        };
        st.addEventListener(MouseEvent.MOUSE_MOVE, stagePanMove);
        st.addEventListener(MouseEvent.MOUSE_UP, stagePanUp);
        if (middle)
            st.addEventListener(MouseEvent.MIDDLE_MOUSE_UP, stagePanUp);
    }

    function endPan():Void {
        if (!panning)
            return;
        panning = false;
        var st = Lib.current.stage;
        if (stagePanMove != null) {
            st.removeEventListener(MouseEvent.MOUSE_MOVE, stagePanMove);
            stagePanMove = null;
        }
        if (stagePanUp != null) {
            st.removeEventListener(MouseEvent.MOUSE_UP, stagePanUp);
            st.removeEventListener(MouseEvent.MIDDLE_MOUSE_UP, stagePanUp);
            stagePanUp = null;
        }
    }

    static function clampf(v:Float, lo:Float, hi:Float):Float {
        if (v < lo)
            return lo;
        if (v > hi)
            return hi;
        return v;
    }
}
