package renderers;

import openfl.display.Sprite;
import openfl.display.Shape;
import openfl.display.GradientType;
import openfl.geom.Point;
import openfl.geom.Matrix;
import openfl.text.TextField;
import openfl.text.TextFieldAutoSize;
import openfl.text.TextFormat;
import interfaces.IBoardRenderer;
import config.GameConfig;

/**
 * Handles rendering the chess board with rounded corners and outline
 */
class BoardRenderer extends Sprite implements IBoardRenderer {
    private var tileSize:Int;
    private var boardShape:Shape;
    private var maskShape:Shape;
    private var coordLayer:Sprite;
    private var borderThickness:Int = 3;
    private var cornerRadius:Int = 12;
    private var checkHighlights:Array<Point>;
    private var lastMoveFrom:Null<Point>;
    private var lastMoveTo:Null<Point>;
    
    public function new(tileSize:Int) {
        super();
        this.tileSize = tileSize;
        boardShape = new Shape();
        addChild(boardShape);
        coordLayer = new Sprite();
        coordLayer.mouseEnabled = false;
        coordLayer.mouseChildren = false;
        addChild(coordLayer);

        // Create and apply mask for rounded corners
        createMask();
    }
    
    private function createMask():Void {
        if (maskShape != null) {
            if (maskShape.parent == this)
                removeChild(maskShape);
            maskShape = null;
        }
        maskShape = new Shape();
        var boardWidth = GameConfig.boardCols * tileSize;
        var boardHeight = GameConfig.boardRows * tileSize;

        maskShape.graphics.beginFill(0x000000);
        maskShape.graphics.drawRoundRect(0, 0, boardWidth, boardHeight, cornerRadius, cornerRadius);
        maskShape.graphics.endFill();

        addChild(maskShape);
        boardShape.mask = maskShape;
    }

    public function setTileSize(size:Int):Void {
        if (size < 8)
            return;
        tileSize = size;
        createMask();
    }

    /**
     * Set which royal pieces are in check (to draw red gradient behind them)
     */
    public function setCheckHighlights(royalPositions:Array<Point>):Void {
        checkHighlights = royalPositions;
    }
    
    public function render(?selectedTile:Point, ?hints:Array<Point>, ?captureHints:Array<Point>, ?lastMoveFrom:Point, ?lastMoveTo:Point):Void {
        this.lastMoveFrom = lastMoveFrom;
        this.lastMoveTo = lastMoveTo;
        boardShape.graphics.clear();
        
        // Draw tiles
        for (row in 0...GameConfig.boardRows) {
            for (col in 0...GameConfig.boardCols) {
                var color = getTileColor(row, col, selectedTile, hints);
                drawTile(row, col, color);
            }
        }
        
        // Draw check highlights (red gradient behind royal pieces)
        if (checkHighlights != null && checkHighlights.length > 0) {
            drawCheckHighlights();
        }

        drawCoordinates();
        
        // Draw capture hints (hollow circles) first so they appear on top
        if (captureHints != null) {
            drawCaptureHints(captureHints);
        }
        
        // Draw hint dots for empty squares
        if (hints != null) {
            drawHintDots(hints);
        }
        
        // Draw rounded border around entire board
        drawBorder();
    }
    
    private function drawBorder():Void {
        var boardWidth = GameConfig.boardCols * tileSize;
        var boardHeight = GameConfig.boardRows * tileSize;
        
        // Draw rounded rectangle border
        boardShape.graphics.lineStyle(borderThickness, 0x333333, 1.0);
        boardShape.graphics.drawRoundRect(0, 0, boardWidth, boardHeight, cornerRadius, cornerRadius);
    }
    
    private function drawHintDots(hints:Array<Point>):Void {
        var dotRadius:Float = tileSize * 0.15; // Dot is 15% of tile size
        
        boardShape.graphics.beginFill(GameConfig.COLOR_HINT);
        for (h in hints) {
            var centerX = Std.int(h.x * tileSize + tileSize / 2);
            var centerY = Std.int(h.y * tileSize + tileSize / 2);
            boardShape.graphics.drawCircle(centerX, centerY, dotRadius);
        }
        boardShape.graphics.endFill();
    }
    
    private function drawCaptureHints(captureHints:Array<Point>):Void {
        var radius:Float = tileSize * 0.4; // Circle radius is 40% of tile size
        
        boardShape.graphics.lineStyle(4, GameConfig.COLOR_HINT, 1.0);
        for (h in captureHints) {
            var centerX = Std.int(h.x * tileSize + tileSize / 2);
            var centerY = Std.int(h.y * tileSize + tileSize / 2);
            boardShape.graphics.drawCircle(centerX, centerY, radius);
        }
        boardShape.graphics.lineStyle();
    }

    private function drawCheckHighlights():Void {
        for (pos in checkHighlights) {
            var x = Std.int(pos.x * tileSize);
            var y = Std.int(pos.y * tileSize);
            
            // Create gradient matrix
            var matrix = new Matrix();
            matrix.createGradientBox(tileSize, tileSize, 0, x, y);
            
            // Draw gradient rectangle with transparency
            boardShape.graphics.beginGradientFill(
                GradientType.RADIAL,
                [0xFF0000, 0x880000],
                [0.9, 0.6],  // Alpha values
                [0, 255],
                matrix
            );
            boardShape.graphics.drawRect(x, y, tileSize, tileSize);
            boardShape.graphics.endFill();
        }
    }

    private function drawCoordinates():Void {
        while (coordLayer.numChildren > 0) {
            coordLayer.removeChildAt(0);
        }

        var fmt = new TextFormat("Arial", Std.int(tileSize * 0.18), 0xFFFFFF, true);
        // coordLayer sits inside the board below piece sprites — labels never draw on top of pieces.
        var padCorner = 0;
        var bottomRow = GameConfig.boardRows - 1;

        // Letters a–h: only on the bottom rank, flush bottom-right of each tile (tight auto-sized box).
        for (col in 0...GameConfig.boardCols) {
            var fileChar = String.fromCharCode("a".code + col);
            var tf = new TextField();
            fmt.color = getCoordTextColor(bottomRow, col);
            tf.defaultTextFormat = fmt;
            tf.selectable = false;
            tf.mouseEnabled = false;
            tf.autoSize = TextFieldAutoSize.LEFT;
            tf.text = fileChar;
            tf.x = col * tileSize + tileSize - tf.width - padCorner;
            tf.y = bottomRow * tileSize + tileSize - tf.height - padCorner;
            coordLayer.addChild(tf);
        }

        // Rank numbers: top-left of each a-file square only.
        for (row in 0...GameConfig.boardRows) {
            var rankNum = Std.string(GameConfig.boardRows - row);
            var tf = new TextField();
            fmt.color = getCoordTextColor(row, 0);
            tf.defaultTextFormat = fmt;
            tf.selectable = false;
            tf.mouseEnabled = false;
            tf.autoSize = TextFieldAutoSize.LEFT;
            tf.text = rankNum;
            tf.x = padCorner;
            tf.y = row * tileSize + padCorner;
            coordLayer.addChild(tf);
        }
    }
    
    public function clearHighlights():Void {
        render(null, null, null, null, null);
    }
    
    public function getTileSize():Int {
        return tileSize;
    }
    
    private function getTileColor(row:Int, col:Int, ?selectedTile:Point, ?hints:Array<Point>):Int {
        var isSelected = isTileSelected(row, col, selectedTile);
        
        if (isSelected) return GameConfig.COLOR_SELECTED;
        if (lastMoveFrom != null && lastMoveFrom.x == col && lastMoveFrom.y == row)
            return GameConfig.COLOR_LAST_MOVE_FROM;
        if (lastMoveTo != null && lastMoveTo.x == col && lastMoveTo.y == row)
            return GameConfig.COLOR_LAST_MOVE_TO;
        var isDefaultLight = (row + col) % 2 == 0;
        if (isDefaultLight) return GameConfig.COLOR_LIGHT;
        return GameConfig.COLOR_DARK;
    }
    
    private function drawTile(row:Int, col:Int, color:Int):Void {
        boardShape.graphics.beginFill(color);
        boardShape.graphics.drawRect(col * tileSize, row * tileSize, tileSize, tileSize);
        boardShape.graphics.endFill();
    }
    
    private function isTileSelected(row:Int, col:Int, selectedTile:Point):Bool {
        return selectedTile != null && selectedTile.x == col && selectedTile.y == row;
    }
    
    private function isTileInHints(row:Int, col:Int, hints:Array<Point>):Bool {
        if (hints == null) return false;
        for (h in hints) {
            if (h.x == col && h.y == row) return true;
        }
        return false;
    }

    private function getCoordTextColor(row:Int, col:Int):Int {
        var isLight = (row + col) % 2 == 0;
        return isLight ? 0x333333 : 0xEAEAEA;
    }
}