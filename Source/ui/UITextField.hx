package ui;

import openfl.display.Sprite;
import openfl.display.Shape;
import openfl.events.Event;
import openfl.events.FocusEvent;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.text.TextFieldType;

/**
 * A text input field for the UI
 */
class UITextField extends Sprite {
    private var textField:TextField;
    private var bg:Shape;
    private var placeholder:String;
    private var _width:Int;
    private var _height:Int;
    private var bgColor:Int;
    private var borderColor:Int;
    private var focusBorderColor:Int;
    private var isFocused:Bool = false;
    
    public function new(width:Int, height:Int, placeholder:String = "", bgColor:Int = 0x2A2A2A, borderColor:Int = 0x555555, focusBorderColor:Int = 0x4CAF50) {
        super();
        
        this._width = width;
        this._height = height;
        this.placeholder = placeholder;
        this.bgColor = bgColor;
        this.borderColor = borderColor;
        this.focusBorderColor = focusBorderColor;
        
        drawBackground();
        createTextField();
        setupEventListeners();
    }
    
    private function drawBackground():Void {
        bg = new Shape();
        drawBorder(borderColor);
        addChild(bg);
    }
    
    private function drawBorder(color:Int):Void {
        bg.graphics.clear();
        bg.graphics.beginFill(bgColor);
        bg.graphics.lineStyle(2, color);
        bg.graphics.drawRoundRect(0, 0, _width, _height, 4, 4);
        bg.graphics.endFill();
    }
    
    private function createTextField():Void {
        textField = new TextField();
        textField.type = TextFieldType.INPUT;
        textField.defaultTextFormat = new TextFormat("Arial", 12, 0xFFFFFF);
        textField.width = _width - 10;
        textField.height = _height - 4;
        textField.x = 5;
        textField.y = 2;
        textField.text = placeholder;
        textField.setTextFormat(new TextFormat("Arial", 12, 0x888888));
        textField.background = false;
        textField.border = false;
        addChild(textField);
    }
    
    private function setupEventListeners():Void {
        textField.addEventListener(FocusEvent.FOCUS_IN, onFocusIn);
        textField.addEventListener(FocusEvent.FOCUS_OUT, onFocusOut);
        textField.addEventListener(Event.CHANGE, onTextChange);
    }
    
    private function onFocusIn(e:FocusEvent):Void {
        isFocused = true;
        drawBorder(focusBorderColor);
        
        // Clear placeholder if showing
        if (textField.text == placeholder) {
            textField.text = "";
            textField.defaultTextFormat = new TextFormat("Arial", 12, 0xFFFFFF);
        }
    }
    
    private function onFocusOut(e:FocusEvent):Void {
        isFocused = false;
        drawBorder(borderColor);
        
        // Show placeholder if empty
        if (textField.text == "") {
            textField.text = placeholder;
            textField.setTextFormat(new TextFormat("Arial", 12, 0x888888));
        }
        
        dispatchEvent(new Event(Event.CHANGE));
    }
    
    private function onTextChange(e:Event):Void {
        // Forward the change event
        dispatchEvent(new Event(Event.CHANGE));
    }
    
    /**
     * Get the current text value
     */
    public function getText():String {
        if (textField.text == placeholder) return "";
        return textField.text;
    }
    
    /**
     * Set the text value
     */
    public function setText(text:String):Void {
        textField.text = text;
        if (text == "" || text == placeholder) {
            textField.text = placeholder;
            textField.setTextFormat(new TextFormat("Arial", 12, 0x888888));
        } else {
            textField.defaultTextFormat = new TextFormat("Arial", 12, 0xFFFFFF);
        }
    }
    
    /**
     * Get the underlying TextField
     */
    public function getTextField():TextField {
        return textField;
    }

    public function setFieldSize(width:Int, height:Int):Void {
        _width = width;
        _height = height;
        drawBorder(isFocused ? focusBorderColor : borderColor);
        textField.width = _width - 10;
        textField.height = _height - 4;
    }
}