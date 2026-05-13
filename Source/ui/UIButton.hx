package ui;

import openfl.display.Sprite;
import openfl.display.Shape;
import openfl.events.MouseEvent;
import openfl.text.TextField;
import openfl.text.TextFormat;

/**
 * Simple text button for the UI.
 */
class UIButton extends Sprite {
    private var _buttonWidth:Int;
    private var _buttonHeight:Int;
    private var bgColor:Int;
    private var hoverColor:Int;
    private var shape:Shape;
    private var textField:TextField;
    private var onClickCallback:Void->Void;

    public function new(btnWidth:Int, btnHeight:Int, label:String, bgColor:Int = 0x444444, hoverColor:Int = 0x666666) {
        super();

        this._buttonWidth = btnWidth;
        this._buttonHeight = btnHeight;
        this.bgColor = bgColor;
        this.hoverColor = hoverColor;

        shape = new Shape();
        addChild(shape);

        textField = new TextField();
        textField.defaultTextFormat = new TextFormat("Arial", 10, 0xFFFFFF, true);
        textField.text = label;
        textField.selectable = false;
        textField.width = btnWidth;
        textField.height = btnHeight;
        addChild(textField);

        textField.x = 0;
        textField.y = (btnHeight - textField.textHeight) / 2 - 2;

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
    }

    public function setButtonSize(btnWidth:Int, btnHeight:Int):Void {
        _buttonWidth = btnWidth;
        _buttonHeight = btnHeight;
        textField.width = btnWidth;
        textField.height = btnHeight;
        textField.y = (btnHeight - textField.textHeight) / 2 - 2;
        draw();
    }

    private function onMouseOver(e:MouseEvent):Void {
        shape.graphics.clear();
        shape.graphics.beginFill(hoverColor);
        shape.graphics.drawRoundRect(0, 0, _buttonWidth, _buttonHeight, 4, 4);
        shape.graphics.endFill();
    }

    private function onMouseOut(e:MouseEvent):Void {
        draw();
    }

    private function onButtonClick(e:MouseEvent):Void {
        if (onClickCallback != null)
            onClickCallback();
    }

    public function setOnClick(callback:Void->Void):Void {
        onClickCallback = callback;
    }

    public function setOnOnClick(callback:Void->Void):Void {
        onClickCallback = callback;
    }

    public function setLabel(label:String):Void {
        textField.text = label;
        textField.y = (_buttonHeight - textField.textHeight) / 2 - 2;
    }
}
