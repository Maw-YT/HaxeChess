package engine;

import config.BoardLayout;

typedef PerftCase = {
    var depth:Int;
    var expected:Int;
};

class PerftSuite {
    /**
     * Stage-1 correctness smoke checks for orthodox start position.
     * Expected perft values: d1=20, d2=400, d3=8902.
     */
    public static function runStandardStartSuite():{passed:Bool, details:Array<String>} {
        var details:Array<String> = [];
        var cases:Array<PerftCase> = [
            {depth: 1, expected: 20},
            {depth: 2, expected: 400},
            {depth: 3, expected: 8902}
        ];

        var allOk = true;
        for (c in cases) {
            var pos = new Position(BoardLayout.getClassicLayout(), "w");
            var got = Perft.run(pos, c.depth);
            var ok = got == c.expected;
            if (!ok)
                allOk = false;
            details.push("perft(" + c.depth + "): got " + got + ", expected " + c.expected + (ok ? " [OK]" : " [FAIL]"));
        }

        return {passed: allOk, details: details};
    }
}
