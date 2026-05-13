package utils;

/** Small integer helpers used by layout and input code. */
class IntBounds {
    public static function clampi(v:Int, lo:Int, hi:Int):Int {
        if (v < lo)
            return lo;
        if (v > hi)
            return hi;
        return v;
    }
}
