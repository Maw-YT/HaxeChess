package ui;

import config.GameConfig;
import openfl.display.Bitmap;
import openfl.display.Sprite;
import openfl.utils.Assets;

/**
 * A clickable promotion button showing a piece image
 */
class PromotionButton extends Sprite {
    private var pieceName:String;
    private var color:String;
    private var onClickCallback:Void->Void;
    private var btnSize:Float;
    
    public function new(pieceName:String, color:String, size:Float = 64) {
        super();
        this.pieceName = pieceName;
        this.color = color;
        this.btnSize = size;

        graphics.beginFill(0x444444);
        graphics.drawRoundRect(0, 0, size, size, 15, 15);
        graphics.endFill();

        var assetPath = GameConfig.ASSETS_PATH + pieceName + "-" + color + ".png";
        if (!Assets.exists(assetPath))
            assetPath = GameConfig.ASSETS_PATH + GameConfig.MISSING_ASSET;

        var bmp = new Bitmap(Assets.getBitmapData(assetPath));
        bmp.smoothing = true;
        var iw = size * 0.78;
        var ih = size * 0.78;
        bmp.width = iw;
        bmp.height = ih;
        bmp.x = (size - iw) * 0.5;
        bmp.y = (size - ih) * 0.5;
        addChild(bmp);

        buttonMode = true;
        useHandCursor = true;

        addEventListener(openfl.events.MouseEvent.CLICK, onButtonClick);
        addEventListener(openfl.events.MouseEvent.MOUSE_OVER, onMouseOver);
        addEventListener(openfl.events.MouseEvent.MOUSE_OUT, onMouseOut);
    }
    
    private function onButtonClick(e:openfl.events.MouseEvent):Void {
        if (onClickCallback != null) {
            onClickCallback();
        }
    }
    
    private function onMouseOver(e:openfl.events.MouseEvent):Void {
        alpha = 0.7;
    }
    
    private function onMouseOut(e:openfl.events.MouseEvent):Void {
        alpha = 1.0;
    }
    
    public function setOnClick(callback:Void->Void):Void {
        onClickCallback = callback;
    }
}
