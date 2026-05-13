package ui;

import openfl.display.Sprite;
import openfl.display.Shape;
import openfl.events.MouseEvent;
import openfl.text.TextField;
import openfl.text.TextFormat;
import utils.ChessNotation;

/**
 * Scrollable move list (UCI formatted as e2–e4) on the right of the board.
 */
class MoveHistoryPanel extends Sprite {
    private var bg:Shape;
    private var tf:TextField;
    private var _width:Int;
    private var _height:Int;

    public function new(w:Int, h:Int) {
        super();
        _width = w;
        _height = h;

        bg = new Shape();
        bg.graphics.beginFill(0x252525, 1);
        bg.graphics.lineStyle(1, 0x444444);
        bg.graphics.drawRoundRect(0, 0, w, h, 8, 8);
        bg.graphics.endFill();
        addChild(bg);

        tf = new TextField();
        tf.defaultTextFormat = new TextFormat("_sans", 12, 0xDDDDDD, false);
        tf.embedFonts = false;
        tf.selectable = true;
        tf.multiline = true;
        tf.wordWrap = true;
        tf.x = 8;
        tf.y = 8;
        tf.width = w - 16;
        tf.height = h - 16;
        tf.text = "";
        addChild(tf);

        addEventListener(MouseEvent.MOUSE_WHEEL, onPanelWheelCapture, true);
    }

    public function getPanelWidth():Int {
        return _width;
    }

    public function resize(w:Int, h:Int):Void {
        _width = w;
        _height = h;
        bg.graphics.clear();
        bg.graphics.beginFill(0x252525, 1);
        bg.graphics.lineStyle(1, 0x444444);
        bg.graphics.drawRoundRect(0, 0, w, h, 8, 8);
        bg.graphics.endFill();
        tf.width = w - 16;
        tf.height = h - 16;
    }

    function onPanelWheelCapture(e:MouseEvent):Void {
        if (tf.maxScrollV <= 1)
            return;
        var next = tf.scrollV - e.delta;
        if (next < 1)
            next = 1;
        var maxV = tf.maxScrollV;
        if (next > maxV)
            next = maxV;
        tf.scrollV = next;
        e.stopImmediatePropagation();
    }

    public function setMoves(history:Array<String>, ?gameState:String):Void {
        var body = formatHistory(history);
        if (gameState == "draw_repetition")
            body += "\n\nDraw — threefold repetition";
        else if (gameState == "draw_material")
            body += "\n\nDraw — insufficient material";
        else if (gameState == "stalemate")
            body += "\n\nStalemate — draw";
        else if (gameState == "checkmate")
            body += "\n\nCheckmate";
        else if (gameState == "win_white")
            body += "\n\nWhite wins — all black pieces captured (no royals on board)";
        else if (gameState == "win_black")
            body += "\n\nBlack wins — all white pieces captured (no royals on board)";
        else if (gameState == "draw_no_royals")
            body += "\n\nDraw — empty board (no royals)";
        tf.text = body;
        tf.scrollV = tf.maxScrollV;
    }

    private static function formatUci(uci:String):String {
        if (uci == null || uci.length < 4)
            return uci;
        var m = ChessNotation.parseUCI(uci);
        if (m == null)
            return uci;
        var fromSq = ChessNotation.colToFile(m.fromCol) + ChessNotation.rowToRank(m.fromRow);
        var toSq = ChessNotation.colToFile(m.toCol) + ChessNotation.rowToRank(m.toRow);
        var promo = m.promotion != null && m.promotion != "" ? m.promotion : "";
        return fromSq + "-" + toSq + promo;
    }

    private static function formatHistory(history:Array<String>):String {
        if (history == null || history.length == 0)
            return "Moves\n—";

        var lines:Array<String> = [];
        var i = 0;
        var n = 1;
        while (i < history.length) {
            var w = formatUci(history[i]);
            i++;
            var b = i < history.length ? formatUci(history[i]) : "";
            if (b != "")
                i++;
            lines.push(n + ". " + w + (b != "" ? "  " + b : ""));
            n++;
        }
        return "Moves\n" + lines.join("\n");
    }
}
