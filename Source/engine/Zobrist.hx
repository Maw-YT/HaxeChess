package engine;

import utils.BoardUtils;
import config.PieceCatalog;

class Zobrist {
    static var ready:Bool = false;
    static var pieceKeys:Map<String, Array<Int>> = new Map();
    static var sideKey:Int;
    static var epFileKeys:Array<Int> = [];
    static var castleKeys:Array<Int> = [];

    static inline function next(seed:Int):Int {
        var x = seed;
        x ^= (x << 13);
        x ^= (x >>> 17);
        x ^= (x << 5);
        return x;
    }

    static function init(boardArea:Int):Void {
        if (ready)
            return;
        var types = PieceCatalog.allTypeIds();
        var pieces:Array<String> = [];
        for (t in types) {
            pieces.push(t + "-w");
            pieces.push(t + "-b");
        }
        var seed = 0x1A2B3C4D;
        for (id in pieces) {
            var arr:Array<Int> = [];
            for (i in 0...boardArea) {
                seed = next(seed);
                arr.push(seed);
            }
            pieceKeys.set(id, arr);
        }
        seed = next(seed);
        sideKey = seed;
        for (i in 0...16) {
            seed = next(seed);
            castleKeys.push(seed);
        }
        for (i in 0...26) {
            seed = next(seed);
            epFileKeys.push(seed);
        }
        ready = true;
    }

    public static function hash(board:Array<Array<String>>, sideToMove:String, castlingMask:Int, epCol:Int):Int {
        var rows = board != null ? board.length : 0;
        var cols = rows > 0 && board[0] != null ? board[0].length : 8;
        var area = rows * cols;
        init(area > 0 ? area : 64);
        var h = 0;
        if (board != null) {
            for (r in 0...rows) {
                var row = board[r];
                if (row == null)
                    continue;
                for (c in 0...row.length) {
                    var id = row[c];
                    if (id == "")
                        continue;
                    var idx = r * cols + c;
                    var arr = pieceKeys.get(id);
                    if (arr != null && idx >= 0 && idx < arr.length)
                        h ^= arr[idx];
                }
            }
        }
        if (sideToMove == "b")
            h ^= sideKey;
        h ^= castleKeys[castlingMask & 15];
        if (epCol >= 0 && epCol < epFileKeys.length)
            h ^= epFileKeys[epCol];
        return h;
    }

    public static function invalidate():Void {
        ready = false;
    }
}
