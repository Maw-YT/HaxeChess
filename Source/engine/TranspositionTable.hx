package engine;

typedef TTEntry = {
    var key:String;
    var depth:Int;
    var score:Int;
    var bound:Int; // 0 exact, 1 lower, 2 upper
    var bestMove:String;
    var generation:Int;
};

class TranspositionTable {
    public static inline var BOUND_EXACT:Int = 0;
    public static inline var BOUND_LOWER:Int = 1;
    public static inline var BOUND_UPPER:Int = 2;

    var table:Map<String, TTEntry> = new Map();
    var maxEntries:Int;
    var entryCount:Int = 0;
    var generation:Int = 0;

    public function new(maxEntries:Int = 200000) {
        this.maxEntries = maxEntries;
    }

    public function clear():Void {
        table = new Map();
        entryCount = 0;
        generation = 0;
    }

    public function nextGeneration():Void {
        generation++;
    }

    public function currentGeneration():Int {
        return generation;
    }

    public function probe(key:String):Null<TTEntry> {
        return table.exists(key) ? table.get(key) : null;
    }

    public function store(key:String, entry:TTEntry):Void {
        entry.key = key;
        entry.generation = generation;
        var old = table.get(key);
        if (old != null && old.depth > entry.depth && old.generation >= generation - 1)
            return;
        if (old == null)
            entryCount++;
        table.set(key, entry);
        if (entryCount > maxEntries) {
            evictOldEntries();
        }
    }

    function evictOldEntries():Void {
        var kill:Array<String> = [];
        for (k => v in table) {
            if (v.generation < generation - 2 || v.depth <= 1)
                kill.push(k);
            if (kill.length >= Std.int(maxEntries * 0.25))
                break;
        }
        for (k in kill) {
            if (table.remove(k))
                entryCount--;
        }
        if (entryCount > maxEntries) {
            table = new Map();
            entryCount = 0;
        }
    }
}
