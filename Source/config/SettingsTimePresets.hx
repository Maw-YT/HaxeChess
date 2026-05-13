package config;

/** Maps settings time-control preset ids to initial milliseconds (0 = untimed). */
class SettingsTimePresets {
    public static function presetToMs(preset:String):Int {
        return switch (preset) {
            case "rapid": 10 * 60 * 1000;
            case "blitz": 3 * 60 * 1000;
            case "bullet": 60 * 1000;
            default: 0;
        };
    }
}
