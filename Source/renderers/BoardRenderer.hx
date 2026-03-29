package renderers;

import openfl.display.Sprite;
import openfl.display.Shape;
import openfl.geom.Point;
import interfaces.IBoardRenderer;
import config.GameConfig;

/**
 * Handles rendering the chess board with rounded corners and outline
 */
class BoardRenderer extends Sprite implements IBoardRenderer {
    private var tileSize:Int;
    private var boardShape:Shape;
    private var borderThickness:Int = 3;
    private var cornerRadius:Int = 12;
    
    public function new(tileSize:Int) {
        super();
        this.tileSize = tileSize;
        boardShape = new Shape();
        addChild(boardShape);
        
        // Create and apply mask for rounded corners
        createMask();
    }
    
    private function createMask():Void {
        var maskShape = new Shape();
        var boardWidth = GameConfig.BOARD_SIZE * tileSize;
        var boardHeight = GameConfig.BOARD_SIZE * tileSize;
        
        maskShape.graphics.beginFill(0x000000);
        maskShape.graphics.drawRoundRect(0, 0, boardWidth, boardHeight, cornerRadius, cornerRadius);
        maskShape.graphics.endFill();
        
        addChild(maskShape);
        boardShape.mask = maskShape;
    }
    
    public function render(?selectedTile:Point, ?hints:Array<Point>):Void {
        boardShape.graphics.clear();
        
        // Draw tiles
        for (row in 0...GameConfig.BOARD_SIZE) {
            for (col in 0...GameConfig.BOARD_SIZE) {
                var color = getTileColor(row, col, selectedTile, hints);
                drawTile(row, col, color);
            }
        }
        
        // Draw hint dots
        if (hints != null) {
            drawHintDots(hints);
        }
        
        // Draw rounded border around entire board
        drawBorder();
    }
    
    private function drawBorder():Void {
        var boardWidth = GameConfig.BOARD_SIZE * tileSize;
        var boardHeight = GameConfig.BOARD_SIZE * tileSize;
        
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
    
    public function clearHighlights():Void {
        render(null, null);
    }
    
    public function getTileSize():Int {
        return tileSize;
    }
    
    private function getTileColor(row:Int, col:Int, ?selectedTile:Point, ?hints:Array<Point>):Int {
        var isDefaultLight = (row + col) % 2 == 0;
        var isDefaultDark = !isDefaultLight;
        var isSelected = isTileSelected(row, col, selectedTile);
        
        if (isSelected) return GameConfig.COLOR_SELECTED;
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
}