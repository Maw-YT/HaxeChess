package engine;

typedef TablebaseProbe = {
    var score:Int;
    var bestMoveUci:String;
    var exact:Bool;
};

class Tablebase {
    public static var enabled:Bool = false;
    public static var path:String = "";

    public static function configure(p:String):Void {
        path = p != null ? p : "";
        enabled = path != "";
    }

    public static function probe(pos:Position):Null<TablebaseProbe> {
        if (!enabled || pos == null)
            return null;
        // Stub hook: later integrate real WDL/DTZ probing.
        return null;
    }
}
