package ui;

import openfl.display.Sprite;
import openfl.display.Bitmap;
import openfl.display.Loader;
import openfl.net.URLRequest;
import openfl.events.Event;
import openfl.events.IOErrorEvent;

/**
 * A clickable promotion button showing a piece image
 */
class PromotionButton extends Sprite {
    private var pieceName:String;
    private var color:String;
    private var onClickCallback:Void->Void;
    private var targetSize:Float;
    
    public function new(pieceName:String, color:String, size:Float = 64) {
        super();
        this.pieceName = pieceName;
        this.color = color;
        this.targetSize = size * 1.2; // Button size slightly larger than image for padding

        // 1. Draw the Rounded Rectangle Background
        graphics.beginFill(0x444444); // Dark grey color
        graphics.drawRoundRect(0, 0, size, size, 15, 15); // x, y, width, height, ellipseW, ellipseH
        graphics.endFill();

        // 2. Load the image
        var imagePath = "Assets/" + pieceName + "-" + color + ".png";
        var loader = new Loader();
        loader.contentLoaderInfo.addEventListener(Event.COMPLETE, onLoadComplete);
        loader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, onLoadError);
        
        try {
            loader.load(new URLRequest(imagePath));
        } catch (e:Dynamic) {
            trace("Error loading piece image: " + imagePath + " - " + e);
        }
        
        buttonMode = true;
        useHandCursor = true;
        
        addEventListener(openfl.events.MouseEvent.CLICK, onButtonClick);
        addEventListener(openfl.events.MouseEvent.MOUSE_OVER, onMouseOver);
        addEventListener(openfl.events.MouseEvent.MOUSE_OUT, onMouseOut);
    }
    
    private function onLoadComplete(e:Event):Void {
        var loader:Loader = cast(e.currentTarget.loader);
        var image = loader.content;

        // 3. Resize the image to fit inside the button
        image.width = targetSize * 0.8;  // Slightly smaller than background for padding
        image.height = targetSize * 0.8;
        
        // Center the image on the rectangle
        image.x = (targetSize - image.width) / 2;
        image.y = (targetSize - image.height) / 2;

        if (Std.isOfType(image, Bitmap)) {
            cast(image, Bitmap).smoothing = true; 
        }

        addChild(image); // Renders above the graphics background
    }
    
    private function onLoadError(e:IOErrorEvent):Void {
        trace("Failed to load piece image: " + pieceName + "-" + color + " - " + e.text);
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
