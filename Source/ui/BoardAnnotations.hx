package ui;

import openfl.display.Sprite;
import openfl.display.Shape;
import openfl.display.Graphics;

/**
 * User-drawn square highlights (below pieces) and arrows (above pieces).
 */
class BoardAnnotations {
    private var tileSize:Int;
    public var belowPieces(default, null):Sprite;
    public var abovePieces(default, null):Sprite;
    private var belowShape:Shape;
    private var aboveShape:Shape;
    private var highlights:Map<String, Bool>;
    private var arrows:Array<ArrowSeg>;

    private static inline var HIGHLIGHT_COLOR:UInt = 0xFFFF44;
    private static inline var ARROW_COLOR:UInt = 0x33CCFF;

    public function setTileSize(size:Int):Void {
        if (size < 8)
            return;
        tileSize = size;
        redraw();
    }

    public function new(tileSize:Int) {
        this.tileSize = tileSize;
        highlights = new Map();
        arrows = [];
        belowPieces = new Sprite();
        abovePieces = new Sprite();
        belowPieces.mouseEnabled = false;
        belowPieces.mouseChildren = false;
        abovePieces.mouseEnabled = false;
        abovePieces.mouseChildren = false;
        belowShape = new Shape();
        aboveShape = new Shape();
        belowPieces.addChild(belowShape);
        abovePieces.addChild(aboveShape);
    }

    public function toggleHighlight(col:Int, row:Int):Void {
        var k = key(col, row);
        if (highlights.exists(k))
            highlights.remove(k);
        else
            highlights.set(k, true);
        redraw();
    }

    public function addArrow(fromCol:Int, fromRow:Int, toCol:Int, toRow:Int):Void {
        arrows.push({fc: fromCol, fr: fromRow, tc: toCol, tr: toRow});
        redraw();
    }

    /** If the same arrow exists, remove it; otherwise add it (right-drag release). */
    public function toggleArrow(fromCol:Int, fromRow:Int, toCol:Int, toRow:Int):Void {
        for (i in 0...arrows.length) {
            var a = arrows[i];
            if (a.fc == fromCol && a.fr == fromRow && a.tc == toCol && a.tr == toRow) {
                arrows.splice(i, 1);
                redraw();
                return;
            }
        }
        addArrow(fromCol, fromRow, toCol, toRow);
    }

    /** Remove arrows that start or end on this square (left-click eraser). */
    public function removeArrowsTouchingSquare(col:Int, row:Int):Void {
        var i = arrows.length;
        while (i-- > 0) {
            var a = arrows[i];
            if ((a.fc == col && a.fr == row) || (a.tc == col && a.tr == row))
                arrows.splice(i, 1);
        }
        redraw();
    }

    public function clearAll():Void {
        highlights = new Map();
        arrows = [];
        redraw();
    }

    public function redraw(?previewFromCol:Null<Int>, ?previewFromRow:Null<Int>, ?previewToCol:Null<Int>, ?previewToRow:Null<Int>):Void {
        belowShape.graphics.clear();
        aboveShape.graphics.clear();

        for (k => _ in highlights) {
            var parts = k.split("-");
            if (parts.length != 2)
                continue;
            var c = Std.parseInt(parts[0]);
            var r = Std.parseInt(parts[1]);
            belowShape.graphics.beginFill(HIGHLIGHT_COLOR, 0.38);
            belowShape.graphics.drawRect(c * tileSize, r * tileSize, tileSize, tileSize);
            belowShape.graphics.endFill();
        }

        for (a in arrows) {
            drawArrow(aboveShape.graphics, a.fc, a.fr, a.tc, a.tr);
        }

        if (previewFromCol != null && previewFromRow != null && previewToCol != null && previewToRow != null) {
            drawArrowLine(aboveShape.graphics, previewFromCol, previewFromRow, previewToCol, previewToRow, ARROW_COLOR, 0.45, false);
        }
    }

    private function drawArrow(g:Graphics, fc:Int, fr:Int, tc:Int, tr:Int):Void {
        drawArrowLine(g, fc, fr, tc, tr, ARROW_COLOR, 0.88, true);
    }

    private function drawArrowLine(g:Graphics, fc:Int, fr:Int, tc:Int, tr:Int, color:UInt, alpha:Float, withHead:Bool):Void {
        var x1 = fc * tileSize + tileSize * 0.5;
        var y1 = fr * tileSize + tileSize * 0.5;
        var x2 = tc * tileSize + tileSize * 0.5;
        var y2 = tr * tileSize + tileSize * 0.5;

        var dx = x2 - x1;
        var dy = y2 - y1;
        var len = Math.sqrt(dx * dx + dy * dy);
        if (len < 4)
            return;

        if (withHead) {
            var inset = tileSize * 0.38;
            if (len > inset * 2) {
                x2 -= (dx / len) * inset;
                y2 -= (dy / len) * inset;
                x1 += (dx / len) * (inset * 0.35);
                y1 += (dy / len) * (inset * 0.35);
            }
        }

        g.lineStyle(5, color, alpha);
        g.moveTo(x1, y1);
        g.lineTo(x2, y2);
        g.lineStyle();

        if (withHead) {
            var ang = Math.atan2(y2 - y1, x2 - x1);
            var headLen = tileSize * 0.28;
            var spread = 0.42;
            g.lineStyle(5, color, alpha);
            g.moveTo(x2, y2);
            g.lineTo(x2 - headLen * Math.cos(ang - spread), y2 - headLen * Math.sin(ang - spread));
            g.moveTo(x2, y2);
            g.lineTo(x2 - headLen * Math.cos(ang + spread), y2 - headLen * Math.sin(ang + spread));
            g.lineStyle();
        }
    }

    private function key(col:Int, row:Int):String {
        return col + "-" + row;
    }
}

private typedef ArrowSeg = {
    var fc:Int;
    var fr:Int;
    var tc:Int;
    var tr:Int;
}
