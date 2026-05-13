package ui;

import openfl.display.Stage;
import config.SettingsConfig;

/** Lime window fullscreen: persist setting and listen for OS-driven changes. */
class WindowFullscreen {
    static var listenerBound:Bool = false;

    public static function ensureListener(stage:Stage, onFullscreenChanged:Void->Void):Void {
        #if lime
        if (listenerBound)
            return;
        if (stage == null || stage.window == null)
            return;
        listenerBound = true;
        stage.window.onFullscreen.add(function() {
            if (stage == null || stage.window == null)
                return;
            SettingsConfig.windowFullscreen = stage.window.fullscreen;
            SettingsConfig.save();
            onFullscreenChanged();
        });
        #end
    }

    public static function applyFromConfig(stage:Stage):Void {
        #if lime
        if (stage == null || stage.window == null)
            return;
        stage.window.fullscreen = SettingsConfig.windowFullscreen;
        #end
    }

    public static function toggleAndSave(stage:Stage, onAfter:Void->Void):Void {
        SettingsConfig.windowFullscreen = !SettingsConfig.windowFullscreen;
        SettingsConfig.save();
        applyFromConfig(stage);
        onAfter();
    }
}
