package config;

import StringTools;

/**
 * User-created board layouts persisted beside settings (sys) or SharedObject (OpenFL).
 */
typedef CustomLayoutEntry = {
    var id:String;
    var name:String;
    var cols:Int;
    var rows:Int;
    var board:Array<Array<String>>;
};

class CustomLayoutsStore {
    static var _instance:CustomLayoutsStore;

    public static var instance(get, never):CustomLayoutsStore;

    static function get_instance():CustomLayoutsStore {
        if (_instance == null)
            _instance = new CustomLayoutsStore();
        return _instance;
    }

    var layouts:Array<CustomLayoutEntry> = [];

    function new() {}

    public function getAll():Array<CustomLayoutEntry> {
        return [for (e in layouts) {
            id: e.id,
            name: e.name,
            cols: e.cols,
            rows: e.rows,
            board: copyBoard(e.board)
        }];
    }

    public function hasId(id:String):Bool {
        if (id == null || id == "")
            return false;
        for (e in layouts)
            if (e.id == id)
                return true;
        return false;
    }

    public function getBoard(id:String):Null<Array<Array<String>>> {
        for (e in layouts)
            if (e.id == id)
                return copyBoard(e.board);
        return null;
    }

    public function getEntry(id:String):Null<CustomLayoutEntry> {
        for (e in layouts)
            if (e.id == id)
                return {
                    id: e.id,
                    name: e.name,
                    cols: e.cols,
                    rows: e.rows,
                    board: copyBoard(e.board)
                };
        return null;
    }

    public function upsert(entry:CustomLayoutEntry):Void {
        for (i in 0...layouts.length) {
            if (layouts[i].id == entry.id) {
                layouts[i] = sanitizeEntry(entry);
                save();
                return;
            }
        }
        layouts.push(sanitizeEntry(entry));
        save();
    }

    /**
     * Create a new layout with a fresh id. Returns the new id.
     */
    public function addNew(name:String, cols:Int, rows:Int, board:Array<Array<String>>):String {
        var id = generateUniqueId();
        layouts.push(sanitizeEntry({
            id: id,
            name: name != null && StringTools.trim(name) != "" ? StringTools.trim(name) : "Untitled layout",
            cols: cols,
            rows: rows,
            board: copyBoard(board)
        }));
        save();
        return id;
    }

    /**
     * Replace board dimensions and content for an existing layout id.
     */
    public function updateExisting(id:String, name:String, cols:Int, rows:Int, board:Array<Array<String>>):Bool {
        for (i in 0...layouts.length) {
            if (layouts[i].id == id) {
                layouts[i] = sanitizeEntry({
                    id: id,
                    name: name != null && StringTools.trim(name) != "" ? StringTools.trim(name) : "Untitled layout",
                    cols: cols,
                    rows: rows,
                    board: copyBoard(board)
                });
                save();
                return true;
            }
        }
        return false;
    }

    public function remove(id:String):Bool {
        for (i in 0...layouts.length) {
            if (layouts[i].id == id) {
                layouts.splice(i, 1);
                save();
                return true;
            }
        }
        return false;
    }

    function sanitizeEntry(e:CustomLayoutEntry):CustomLayoutEntry {
        var c = e.cols < 3 ? 3 : (e.cols > 32 ? 32 : e.cols);
        var r = e.rows < 3 ? 3 : (e.rows > 32 ? 32 : e.rows);
        var b = ensureBoardSize(copyBoard(e.board), c, r);
        return {
            id: e.id,
            name: e.name,
            cols: c,
            rows: r,
            board: b
        };
    }

    function ensureBoardSize(board:Array<Array<String>>, cols:Int, rows:Int):Array<Array<String>> {
        var out:Array<Array<String>> = [];
        for (row in 0...rows) {
            var line:Array<String> = [];
            for (col in 0...cols) {
                var v = "";
                if (board != null && row < board.length) {
                    var br = board[row];
                    if (br != null && col < br.length)
                        v = br[col] != null ? br[col] : "";
                }
                line.push(v);
            }
            out.push(line);
        }
        return out;
    }

    function copyBoard(board:Array<Array<String>>):Array<Array<String>> {
        if (board == null)
            return [];
        return [for (row in board) row != null ? [for (c in row) c] : []];
    }

    function generateUniqueId():String {
        for (_ in 0...64) {
            var id = "custom_" + StringTools.hex(Std.int(Math.random() * 0xFFFFFF), 6)
                + StringTools.hex(Std.int(haxe.Timer.stamp() * 1e6) & 0xFFFFFF, 6);
            if (!hasId(id))
                return id;
        }
        return "custom_" + Std.string(Std.int(Math.random() * 1e12));
    }

    public function load():Void {
        layouts = [];
        try {
            #if sys
            var p = getStorePath();
            if (sys.FileSystem.exists(p)) {
                var raw = sys.io.File.getContent(p);
                parseJson(raw);
            }
            #elseif js
            var raw = js.Browser.window.localStorage.getItem("ChessCustomLayouts");
            if (raw != null)
                parseJson(raw);
            #else
            var so = openfl.utils.SharedObject.getLocal("ChessCustomLayouts");
            var raw = Reflect.field(so.data, "json");
            if (raw != null && Std.isOfType(raw, String))
                parseJson(cast raw);
            #end
        } catch (e:Dynamic) {
            trace("CustomLayoutsStore.load failed: " + e);
            layouts = [];
        }
    }

    public function save():Void {
        try {
            var payload = haxe.Json.stringify({layouts: layouts});
            #if sys
            var p = getStorePath();
            var dir = haxe.io.Path.directory(p);
            if (!sys.FileSystem.exists(dir))
                sys.FileSystem.createDirectory(dir);
            sys.io.File.saveContent(p, payload);
            #elseif js
            js.Browser.window.localStorage.setItem("ChessCustomLayouts", payload);
            #else
            var so = openfl.utils.SharedObject.getLocal("ChessCustomLayouts");
            Reflect.setField(so.data, "json", payload);
            so.flush();
            #end
        } catch (e:Dynamic) {
            trace("CustomLayoutsStore.save failed: " + e);
        }
    }

    function parseJson(raw:String):Void {
        if (raw == null || StringTools.trim(raw) == "")
            return;
        var data = haxe.Json.parse(raw);
        var arr = Reflect.field(data, "layouts");
        if (arr == null || !Std.isOfType(arr, Array))
            return;
        var next:Array<CustomLayoutEntry> = [];
        for (x in cast(arr, Array<Dynamic>)) {
            var id = Reflect.field(x, "id");
            var name = Reflect.field(x, "name");
            var cols = Reflect.field(x, "cols");
            var rows = Reflect.field(x, "rows");
            var board = Reflect.field(x, "board");
            if (id == null || board == null || !Std.isOfType(board, Array))
                continue;
            var idStr = Std.string(id);
            if (!StringTools.startsWith(idStr, "custom_"))
                continue;
            var c = Std.int(cols);
            var r = Std.int(rows);
            if (c < 3)
                c = 3;
            if (c > 32)
                c = 32;
            if (r < 3)
                r = 3;
            if (r > 32)
                r = 32;
            var b = parseBoard(board, c, r);
            next.push({
                id: idStr,
                name: name != null ? Std.string(name) : "Untitled",
                cols: c,
                rows: r,
                board: b
            });
        }
        layouts = next;
    }

    function parseBoard(raw:Dynamic, cols:Int, rows:Int):Array<Array<String>> {
        var arr = cast(raw, Array<Dynamic>);
        var out:Array<Array<String>> = [];
        for (row in 0...rows) {
            var line:Array<String> = [];
            var srcRow:Array<Dynamic> = row < arr.length && Std.isOfType(arr[row], Array) ? cast arr[row] : null;
            for (col in 0...cols) {
                var cell = "";
                if (srcRow != null && col < srcRow.length) {
                    var v = srcRow[col];
                    cell = v != null ? Std.string(v) : "";
                }
                line.push(cell);
            }
            out.push(line);
        }
        return out;
    }

    #if sys
    function getStorePath():String {
        var appData = Sys.getEnv("APPDATA");
        if (appData == null || appData == "")
            appData = Sys.getEnv("HOME");
        if (appData == null)
            appData = ".";
        return appData + "/Chess/custom_layouts.json";
    }
    #end
}
