package utils;

import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.PixelSnapping;
import openfl.display.Sprite;
import openfl.display.Stage;
import openfl.events.Event;
import openfl.geom.Point;
import openfl.ui.Mouse;
import openfl.ui.MouseCursor;
import openfl.utils.Assets;

/**
 * Hover / drag cursors for pieces. Uses hand_grab / hand_grabbing assets (`.cur` or `.png`).
 * Native OpenFL+Lime does not register custom `.cur` as OS cursors; we draw a top-of-stage bitmap
 * and hide the system cursor while grab/grabbing are active.
 */
class PieceCursor {
    static inline var ASSET_GRAB:String = "assets/hand_grab.cur";
    static inline var ASSET_GRAB_PNG:String = "assets/hand_grab.png";
    static inline var ASSET_GRABBING:String = "assets/hand_grabbing.cur";
    static inline var ASSET_GRABBING_PNG:String = "assets/hand_grabbing.png";

    static var stage:Stage;
    static var layer:Sprite;
    static var bmp:Bitmap;
    static var bdGrab:BitmapData;
    static var bdGrabbing:BitmapData;
    static var useSoftware:Bool = false;
    /** 0 = default, 1 = grab, 2 = grabbing */
    static var mode:Int = 0;
    static var hotspot:Point = new Point(0, 0);
    static var hotspotGrab:Point = new Point(0, 0);
    static var hotspotGrabbing:Point = new Point(0, 0);
    static var inited:Bool = false;

    public static function init(st:Stage):Void {
        if (inited)
            return;
        inited = true;
        stage = st;

        bdGrab = loadCursorBitmap(ASSET_GRAB, ASSET_GRAB_PNG);
        bdGrabbing = loadCursorBitmap(ASSET_GRABBING, ASSET_GRABBING_PNG);
        useSoftware = bdGrab != null || bdGrabbing != null;

        if (useSoftware) {
            if (bdGrab == null)
                bdGrab = bdGrabbing;
            if (bdGrabbing == null)
                bdGrabbing = bdGrab;
            hotspotGrab = guessHotspot(bdGrab);
            hotspotGrabbing = guessHotspot(bdGrabbing);
            layer = new Sprite();
            layer.mouseEnabled = false;
            layer.mouseChildren = false;
            bmp = new Bitmap(bdGrab, PixelSnapping.AUTO, true);
            layer.addChild(bmp);
            layer.visible = false;
            stage.addChild(layer);
            stage.addEventListener(Event.RESIZE, onStageResize, false, 0, true);
        }
    }

    static function guessHotspot(bd:BitmapData):Point {
        if (bd == null)
            return new Point(0, 0);
        return new Point(Std.int(bd.width * 0.2), Std.int(bd.height * 0.2));
    }

    static function loadCursorBitmap(curId:String, pngId:String):BitmapData {
        if (Assets.exists(curId)) {
            try {
                return Assets.getBitmapData(curId);
            } catch (_:Dynamic) {}
        }
        if (Assets.exists(pngId)) {
            try {
                return Assets.getBitmapData(pngId);
            } catch (_:Dynamic) {}
        }
        #if (!html5 && !flash)
        var p = Assets.getPath(curId);
        if (p != null) {
            var bd = BitmapData.fromFile(p);
            if (bd != null)
                return bd;
        }
        p = Assets.getPath(pngId);
        if (p != null) {
            var bd2 = BitmapData.fromFile(p);
            if (bd2 != null)
                return bd2;
        }
        #end
        return null;
    }

    public static function setAuto():Void {
        applyMode(0);
    }

    public static function setGrab():Void {
        applyMode(1);
    }

    public static function setGrabbing():Void {
        applyMode(2);
    }

    static function applyMode(m:Int):Void {
        if (mode == m)
            return;
        mode = m;

        if (useSoftware && layer != null && bmp != null) {
            if (m == 0) {
                bmp.visible = false;
                layer.visible = false;
                Mouse.show();
                Mouse.cursor = MouseCursor.AUTO;
            } else {
                bmp.bitmapData = m == 1 ? bdGrab : bdGrabbing;
                hotspot = m == 1 ? hotspotGrab : hotspotGrabbing;
                bmp.visible = true;
                layer.visible = true;
                Mouse.hide();
                bringToFront();
            }
        } else {
            Mouse.show();
            switch (m) {
                case 1, 2:
                    Mouse.cursor = MouseCursor.HAND;
                default:
                    Mouse.cursor = MouseCursor.AUTO;
            }
        }
    }

    static function bringToFront():Void {
        if (stage != null && layer != null && stage.contains(layer))
            stage.setChildIndex(layer, stage.numChildren - 1);
    }

    public static function sync(stageX:Float, stageY:Float):Void {
        if (!useSoftware || mode == 0 || layer == null || !layer.visible)
            return;
        layer.x = stageX - hotspot.x;
        layer.y = stageY - hotspot.y;
        bringToFront();
    }

    static function onStageResize(_:Event):Void {
        bringToFront();
    }
}
