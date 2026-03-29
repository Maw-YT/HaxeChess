package ui;

import openfl.display.Sprite;

/**
 * Grid-based layout system for positioning UI elements
 * Divides space into rows and columns
 */
class UILayout {
    private var container:Sprite;
    private var cols:Int;
    private var rows:Int;
    private var cellWidth:Int;
    private var cellHeight:Int;
    private var gap:Int;
    
    public function new(container:Sprite, cols:Int, rows:Int, cellWidth:Int, cellHeight:Int, gap:Int = 0) {
        this.container = container;
        this.cols = cols;
        this.rows = rows;
        this.cellWidth = cellWidth;
        this.cellHeight = cellHeight;
        this.gap = gap;
    }
    
    /**
     * Position an element at a grid cell
     * col: column index (0-based)
     * row: row index (0-based)
     * colSpan: how many columns this element spans (default 1)
     * rowSpan: how many rows this element spans (default 1)
     */
    public function positionAt(element:Sprite, col:Int, row:Int, colSpan:Int = 1, rowSpan:Int = 1):Void {
        element.x = col * (cellWidth + gap);
        element.y = row * (cellHeight + gap);
    }
    
    /**
     * Get the x position for a column
     */
    public function getColX(col:Int):Int {
        return col * (cellWidth + gap);
    }
    
    /**
     * Get the y position for a row
     */
    public function getRowY(row:Int):Int {
        return row * (cellHeight + gap);
    }
    
    /**
     * Get total width needed for layout
     */
    public function getTotalWidth():Int {
        return cols * cellWidth + (cols - 1) * gap;
    }
    
    /**
     * Get total height needed for layout
     */
    public function getTotalHeight():Int {
        return rows * cellHeight + (rows - 1) * gap;
    }
    
    /**
     * Get cell width
     */
    public function getCellWidth():Int {
        return cellWidth;
    }
    
    /**
     * Get cell height
     */
    public function getCellHeight():Int {
        return cellHeight;
    }
}
