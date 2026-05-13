package utils;

/** Formats remaining clock time for UI labels (ceil to whole seconds, m:ss). */
class ClockFormat {
    public static function formatMsCeilToSeconds(ms:Float):String {
        var total = Std.int(Math.max(0, Math.ceil(ms / 1000)));
        var m = Std.int(total / 60);
        var s = total % 60;
        var ss = (s < 10 ? "0" : "") + Std.string(s);
        return Std.string(m) + ":" + ss;
    }
}
