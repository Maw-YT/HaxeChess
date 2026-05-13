package engine;

class Perft {
    public static function run(pos:Position, depth:Int):Int {
        if (depth <= 0)
            return 1;
        var moves = pos.generateLegalMoves();
        if (depth == 1)
            return moves.length;
        var nodes = 0;
        for (m in moves) {
            pos.makeMove(m);
            nodes += run(pos, depth - 1);
            pos.unmakeMove();
        }
        return nodes;
    }

    public static function divide(pos:Position, depth:Int):Array<{move:String, nodes:Int}> {
        var out:Array<{move:String, nodes:Int}> = [];
        var moves = pos.generateLegalMoves();
        for (m in moves) {
            pos.makeMove(m);
            var n = depth <= 1 ? 1 : run(pos, depth - 1);
            pos.unmakeMove();
            out.push({
                move: utils.ChessNotation.toUCI(m.fromCol, m.fromRow, m.toCol, m.toRow, m.promotion),
                nodes: n
            });
        }
        return out;
    }
}
