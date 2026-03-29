package ui;

import openfl.display.Sprite;
import openfl.display.Shape;
import openfl.events.MouseEvent;
import openfl.text.TextField;
import openfl.text.TextFormat;

/**
 * A simple clickable button for the UI
 */
class UIButton extends Sprite {
    private var _buttonWidth:Int;
    private var _buttonHeight:Int;
    private var bgColor:Int;
    private var hoverColor:Int;
    private var label:String;
    private var iconType:String; // "text", "close", "minimize", "maximize"
    private var shape:Shape;
    private var textField:TextField;
    private var onClickCallback:Void->Void;
    
    public function new(btnWidth:Int, btnHeight:Int, label:String, bgColor:Int = 0x444444, hoverColor:Int = 0x666666, iconType:String = "text") {
        super();
        
        this._buttonWidth = btnWidth;
        this._buttonHeight = btnHeight;
        this.label = label;
        this.bgColor = bgColor;
        this.hoverColor = hoverColor;
        this.iconType = iconType;
        
        // Create background shape
        shape = new Shape();
        addChild(shape);
        
        // Create text or icon based on type
        if (iconType == "text") {
            textField = new TextField();
            textField.defaultTextFormat = new TextFormat("Arial", 10, 0xFFFFFF, true);
            textField.text = label;
            textField.selectable = false;
            textField.width = btnWidth;
            textField.height = btnHeight;
            addChild(textField);
            
            // Center text
            textField.x = 0;
            textField.y = (btnHeight - textField.textHeight) / 2 - 2;
        }
        
        // Setup hover effects
        buttonMode = true;
        useHandCursor = true;
        
        addEventListener(MouseEvent.MOUSE_OVER, onMouseOver);
        addEventListener(MouseEvent.MOUSE_OUT, onMouseOut);
        addEventListener(MouseEvent.CLICK, onButtonClick);
        
        draw();
    }
    
    private function draw():Void {
        shape.graphics.clear();
        shape.graphics.beginFill(bgColor);
        shape.graphics.drawRoundRect(0, 0, _buttonWidth, _buttonHeight, 4, 4);
        shape.graphics.endFill();
        
        // Draw icon if not using text
        if (iconType != "text") {
            drawIcon(0xFFFFFF);
        }
    }
    
    private function drawIcon(color:Int):Void {
        var centerX = _buttonWidth / 2;
        var centerY = _buttonHeight / 2;
        var lineWidth = 2;
        
        shape.graphics.lineStyle(lineWidth, color, 1.0);
        
        if (iconType == "close") {
            // Draw X icon
            var offset = 6;
            shape.graphics.moveTo(centerX - offset, centerY - offset);
            shape.graphics.lineTo(centerX + offset, centerY + offset);
            shape.graphics.moveTo(centerX + offset, centerY - offset);
            shape.graphics.lineTo(centerX - offset, centerY + offset);
        } else if (iconType == "minimize") {
            // Draw horizontal line for minimize
            var offset = 6;
            shape.graphics.moveTo(centerX - offset, centerY);
            shape.graphics.lineTo(centerX + offset, centerY);
        } else if (iconType == "maximize") {
            // Draw square for maximize
            var offset = 5;
            shape.graphics.drawRect(centerX - offset, centerY - offset, offset * 2, offset * 2);
        }
    }
    
    private function onMouseOver(e:MouseEvent):Void {
        shape.graphics.clear();
        shape.graphics.beginFill(hoverColor);
        shape.graphics.drawRoundRect(0, 0, _buttonWidth, _buttonHeight, 4, 4);
        shape.graphics.endFill();
        
        // Redraw icon with lighter color for hover
        if (iconType != "text") {
            drawIcon(0xFFFFFF);
        }
    }
    
    private function onMouseOut(e:MouseEvent):Void {
        draw();
    }
    
    private function onButtonClick(e:MouseEvent):Void {
        if (onClickCallback != null) {
            onClickCallback();
        }
    }
    
    public function setOnClick(callback:Void->Void):Void {
        onClickCallback = callback;
    }
}
