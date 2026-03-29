package renderers;

import openfl.display.Sprite;
import openfl.display.Bitmap;
import openfl.utils.Assets;
import openfl.geom.Point;
import motion.Actuate;
import motion.easing.Linear;
import interfaces.IPieceRenderer;
import config.GameConfig;
import utils.BoardUtils;

/**
 * Handles rendering and animating pieces
 */
class PieceRenderer extends Sprite implements IPieceRenderer {
    private var tileSize:Int;
    private var pieceMap:Map<String, Bitmap>;
    
    public function new(tileSize:Int) {
        super();
        this.tileSize = tileSize;
        this.pieceMap = new Map();
    }

    public function render(boardData:Array<Array<String>>):Void {
        clear();
        
        for (row in 0...GameConfig.BOARD_SIZE) {
            for (col in 0...GameConfig.BOARD_SIZE) {
                createPieceAt(row, col, boardData[row][col]);
            }
        }
    }
    
    public function clear():Void {
        while (numChildren > 0) removeChildAt(0);
        pieceMap = new Map();
    }

    public function animateMove(startR:Int, startC:Int, endR:Int, endC:Int, pieceId:String, callback:Void->Void):Void {
        var key = getKey(startR, startC);
        var bmp = pieceMap.get(key);

        if (bmp != null) {
            var targetKey = getKey(endR, endC);
            
            // Handle capture: remove target piece
            if (pieceMap.exists(targetKey)) {
                removeChild(pieceMap.get(targetKey));
                pieceMap.remove(targetKey);
            }

            pieceMap.remove(key);
            pieceMap.set(targetKey, bmp);

            // Animate the move
            Actuate.tween(bmp, GameConfig.ANIMATION_DURATION, { x: endC * tileSize, y: endR * tileSize })
                .ease(Linear.easeNone) 
                .onComplete(callback);
        } else {
            callback();
        }
    }
    
    /**
     * Animate a castling move (king and rook move simultaneously)
     */
    public function animateCastling(kingStartR:Int, kingStartC:Int, kingEndR:Int, kingEndC:Int, 
                                    rookStartR:Int, rookStartC:Int, rookEndR:Int, rookEndC:Int, callback:Void->Void):Void {
        var kingKey = getKey(kingStartR, kingStartC);
        var rookKey = getKey(rookStartR, rookStartC);
        
        var kingBmp = pieceMap.get(kingKey);
        var rookBmp = pieceMap.get(rookKey);
        
        if (kingBmp != null && rookBmp != null) {
            var kingTargetKey = getKey(kingEndR, kingEndC);
            var rookTargetKey = getKey(rookEndR, rookEndC);
            
            // Update piece map
            pieceMap.remove(kingKey);
            pieceMap.set(kingTargetKey, kingBmp);
            
            pieceMap.remove(rookKey);
            pieceMap.set(rookTargetKey, rookBmp);
            
            // Animate both pieces simultaneously
            Actuate.tween(kingBmp, GameConfig.ANIMATION_DURATION, { x: kingEndC * tileSize, y: kingEndR * tileSize })
                .ease(Linear.easeNone);
                
            Actuate.tween(rookBmp, GameConfig.ANIMATION_DURATION, { x: rookEndC * tileSize, y: rookEndR * tileSize })
                .ease(Linear.easeNone)
                .onComplete(callback);
        } else {
            callback();
        }
    }

    public function updateTile(row:Int, col:Int, newId:String):Void {
        var key = getKey(row, col);
        if (pieceMap.exists(key)) {
            removeChild(pieceMap.get(key));
            pieceMap.remove(key);
        }
        createPieceAt(row, col, newId);
    }
    
    private function createPieceAt(row:Int, col:Int, id:String):Void {
        if (id == "") return;
        
        var assetPath = getAssetPath(id);
        var bmp = new Bitmap(Assets.getBitmapData(assetPath));
        
        bmp.smoothing = true;
        bmp.width = bmp.height = tileSize;
        bmp.x = col * tileSize;
        bmp.y = row * tileSize;
        
        addChild(bmp);
        pieceMap.set(getKey(row, col), bmp);
    }
    
    private function getAssetPath(id:String):String {
        var assetPath = GameConfig.ASSETS_PATH + id + ".png";
        if (!Assets.exists(assetPath)) {
            assetPath = GameConfig.ASSETS_PATH + GameConfig.MISSING_ASSET;
        }
        return assetPath;
    }
    
    private function getKey(row:Int, col:Int):String {
        return row + "-" + col;
    }
}