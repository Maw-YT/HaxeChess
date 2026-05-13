package engine;

typedef IEvalBackend = {
    function id():String;
    function build(board:Array<Array<String>>):Eval.EvalAccumulator;
    function clone(acc:Eval.EvalAccumulator):Eval.EvalAccumulator;
    function updateNormalMove(acc:Eval.EvalAccumulator, movedPieceId:String, fromR:Int, fromC:Int, toR:Int, toC:Int, capturedPieceId:String, boardRows:Int, boardCols:Int):Void;
    function score(acc:Eval.EvalAccumulator, sideToMove:String):Int;
}

class ClassicalEvalBackend {
    public function new() {}

    public function id():String {
        return "classical";
    }

    public function build(board:Array<Array<String>>):Eval.EvalAccumulator {
        return Eval.classicalBuild(board);
    }

    public function clone(acc:Eval.EvalAccumulator):Eval.EvalAccumulator {
        return Eval.classicalClone(acc);
    }

    public function updateNormalMove(acc:Eval.EvalAccumulator, movedPieceId:String, fromR:Int, fromC:Int, toR:Int, toC:Int, capturedPieceId:String, boardRows:Int, boardCols:Int):Void {
        Eval.classicalUpdateNormalMove(acc, movedPieceId, fromR, fromC, toR, toC, capturedPieceId, boardRows, boardCols);
    }

    public function score(acc:Eval.EvalAccumulator, sideToMove:String):Int {
        return Eval.classicalScore(acc, sideToMove);
    }
}

class NnueEvalBackend {
    public var netPath(default, null):String = "";
    public var netLoaded(default, null):Bool = false;
    public var netHash(default, null):String = "";

    var fallback:ClassicalEvalBackend;

    public function new() {
        fallback = new ClassicalEvalBackend();
    }

    public function id():String {
        return "nnue_stub";
    }

    public function loadNet(path:String):Bool {
        netPath = path != null ? path : "";
        netLoaded = netPath != "";
        netHash = netLoaded ? Std.string(netPath.length) : "";
        return netLoaded;
    }

    public function validateNetVersionHash(expectedHash:String):Bool {
        if (!netLoaded)
            return false;
        if (expectedHash == null || expectedHash == "")
            return true;
        return expectedHash == netHash;
    }

    public function build(board:Array<Array<String>>):Eval.EvalAccumulator {
        return fallback.build(board);
    }

    public function clone(acc:Eval.EvalAccumulator):Eval.EvalAccumulator {
        return fallback.clone(acc);
    }

    public function updateNormalMove(acc:Eval.EvalAccumulator, movedPieceId:String, fromR:Int, fromC:Int, toR:Int, toC:Int, capturedPieceId:String, boardRows:Int, boardCols:Int):Void {
        fallback.updateNormalMove(acc, movedPieceId, fromR, fromC, toR, toC, capturedPieceId, boardRows, boardCols);
    }

    public function score(acc:Eval.EvalAccumulator, sideToMove:String):Int {
        return fallback.score(acc, sideToMove);
    }
}
