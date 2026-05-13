package config;

import haxe.io.Path;
import StringTools;

/**
 * Central configuration for game settings
 * Stores and manages user preferences
 */
class SettingsConfig {
    public static inline var BUILTIN_ENGINE_PATH:String = "__builtin__";

    // UCI Engine settings
    public static var uciEnginePath:String = "";

    /** Multiple engine slots; active uses {@link activeEngineId}. */
    public static var engineProfiles:Array<EngineProfile> = [];

    /** Which {@link engineProfiles} entry is used for {@link uciEnginePath} when connecting. */
    public static var activeEngineId:String = "";

    /** Per-engine-profile UCI option name → value (setoption). */
    public static var engineOptionOverrides:Map<String, Map<String, String>> = new Map();
    
    // Engine play settings
    public static var enginePlayAs:String = "black"; // "white", "black", or "both"
    public static var engineDepth:Int = 15;
    public static var engineTimeMs:Int = 1000;
    public static var builtinEvalBackend:String = "classical";
    public static var builtinNetPath:String = "";
    public static var builtinTablebasePath:String = "";

    /** UCI spin options (sent as setoption after connect; empty = skip). */
    public static var engineHashMb:String = "";
    public static var engineThreads:String = "";

    /** Allow moving without chess rules; legal-move hints still shown. */
    public static var allowIllegalMoves:Bool = false;

    /** Preset id from BoardLayout.layoutChoices(). */
    public static var boardLayoutId:String = config.BoardLayout.DEFAULT_LAYOUT_ID;

    /** "none", "rapid", "blitz", "bullet" */
    public static var timeControlPreset:String = "none";

    /** Seconds added to your clock after each move you play (Fischer increment; 0 = none). */
    public static var clockIncrementSeconds:Int = 0;

    /** Native window exclusive fullscreen (Lime `Window.fullscreen`). */
    public static var windowFullscreen:Bool = false;
    
    // Engine status (runtime, not saved)
    public static var engineConnected:Bool = false;
    public static var engineName:String = "";
    
    // Save settings to local storage
    public static function save():Void {
        #if (sys || openfl)
        var optJson:Dynamic = {};
        for (pid => omap in engineOptionOverrides) {
            var inner:Dynamic = {};
            for (k => v in omap)
                Reflect.setField(inner, k, v);
            Reflect.setField(optJson, pid, inner);
        }
        var profArr = [
            for (p in engineProfiles)
                {id: p.id, label: p.label, path: p.path}
        ];
        var savedData = haxe.Json.stringify({
            uciEnginePath: uciEnginePath,
            engineProfiles: profArr,
            activeEngineId: activeEngineId,
            engineOptionOverrides: optJson,
            enginePlayAs: enginePlayAs,
            engineDepth: engineDepth,
            engineTimeMs: engineTimeMs,
            builtinEvalBackend: builtinEvalBackend,
            builtinNetPath: builtinNetPath,
            builtinTablebasePath: builtinTablebasePath,
            engineHashMb: engineHashMb,
            engineThreads: engineThreads,
            allowIllegalMoves: allowIllegalMoves,
            boardLayoutId: boardLayoutId,
            timeControlPreset: timeControlPreset,
            clockIncrementSeconds: clockIncrementSeconds,
            windowFullscreen: windowFullscreen
        });
        
        try {
            #if sys
            // Ensure directory exists
            var settingsPath = getSettingsPath();
            var dir = haxe.io.Path.directory(settingsPath);
            if (!sys.FileSystem.exists(dir)) {
                sys.FileSystem.createDirectory(dir);
            }
            
            var file = sys.io.File.write(settingsPath);
            file.writeString(savedData);
            file.close();
            #elseif js
            js.Browser.window.localStorage.setItem("ChessSettings", savedData);
            #else
            openfl.utils.SharedObject.getLocal("ChessSettings").setData({
                uciEnginePath: uciEnginePath
            });
            openfl.utils.SharedObject.getLocal("ChessSettings").flush();
            #end
        } catch (e:Dynamic) {
            trace("Failed to save settings: " + e);
        }
        #end
    }
    
    // Load settings from local storage
    public static function load():Void {
        #if (sys || openfl)
        try {
            #if sys
            if (sys.FileSystem.exists(getSettingsPath())) {
                var content = sys.io.File.getContent(getSettingsPath());
                var data = haxe.Json.parse(content);
                uciEnginePath = Reflect.field(data, "uciEnginePath") != null ? data.uciEnginePath : "";
                engineProfiles = [];
                engineOptionOverrides = new Map();
                var ep = Reflect.field(data, "engineProfiles");
                if (ep != null && Std.isOfType(ep, Array)) {
                    for (x in cast(ep, Array<Dynamic>)) {
                        var id = Reflect.field(x, "id");
                        var lab = Reflect.field(x, "label");
                        var pth = Reflect.field(x, "path");
                        if (id != null && lab != null && pth != null)
                            engineProfiles.push({id: Std.string(id), label: Std.string(lab), path: Std.string(pth)});
                    }
                }
                activeEngineId = Reflect.field(data, "activeEngineId") != null ? Std.string(data.activeEngineId) : "";
                var eo = Reflect.field(data, "engineOptionOverrides");
                if (eo != null) {
                    for (pid in Reflect.fields(eo)) {
                        var inner = Reflect.field(eo, pid);
                        var m = new Map<String, String>();
                        if (inner != null)
                            for (k in Reflect.fields(inner))
                                m.set(k, Std.string(Reflect.field(inner, k)));
                        engineOptionOverrides.set(pid, m);
                    }
                }
                enginePlayAs = Reflect.field(data, "enginePlayAs") != null ? data.enginePlayAs : "black";
                engineDepth = Reflect.field(data, "engineDepth") != null ? data.engineDepth : 15;
                engineTimeMs = Reflect.field(data, "engineTimeMs") != null ? data.engineTimeMs : 1000;
                builtinEvalBackend = Reflect.field(data, "builtinEvalBackend") != null ? Std.string(data.builtinEvalBackend) : "classical";
                builtinNetPath = Reflect.field(data, "builtinNetPath") != null ? Std.string(data.builtinNetPath) : "";
                builtinTablebasePath = Reflect.field(data, "builtinTablebasePath") != null ? Std.string(data.builtinTablebasePath) : "";
                engineHashMb = Reflect.field(data, "engineHashMb") != null ? data.engineHashMb : "";
                engineThreads = Reflect.field(data, "engineThreads") != null ? data.engineThreads : "";
                allowIllegalMoves = Reflect.field(data, "allowIllegalMoves") == true;
                boardLayoutId = Reflect.field(data, "boardLayoutId") != null ? data.boardLayoutId : config.BoardLayout.DEFAULT_LAYOUT_ID;
                timeControlPreset = Reflect.field(data, "timeControlPreset") != null ? data.timeControlPreset : "none";
                clockIncrementSeconds = Reflect.field(data, "clockIncrementSeconds") != null ? Std.int(data.clockIncrementSeconds) : 0;
                windowFullscreen = Reflect.field(data, "windowFullscreen") == true;
                migrateEngineProfilesIfNeeded();
            } else {
                migrateEngineProfilesIfNeeded();
            }
            #elseif js
            var content = js.Browser.window.localStorage.getItem("ChessSettings");
            if (content != null) {
                var data = haxe.Json.parse(content);
                uciEnginePath = Reflect.field(data, "uciEnginePath") != null ? data.uciEnginePath : "";
                engineProfiles = [];
                engineOptionOverrides = new Map();
                var ep = Reflect.field(data, "engineProfiles");
                if (ep != null && Std.isOfType(ep, Array)) {
                    for (x in cast(ep, Array<Dynamic>)) {
                        var id = Reflect.field(x, "id");
                        var lab = Reflect.field(x, "label");
                        var pth = Reflect.field(x, "path");
                        if (id != null && lab != null && pth != null)
                            engineProfiles.push({id: Std.string(id), label: Std.string(lab), path: Std.string(pth)});
                    }
                }
                activeEngineId = Reflect.field(data, "activeEngineId") != null ? Std.string(data.activeEngineId) : "";
                var eo = Reflect.field(data, "engineOptionOverrides");
                if (eo != null) {
                    for (pid in Reflect.fields(eo)) {
                        var inner = Reflect.field(eo, pid);
                        var m = new Map<String, String>();
                        if (inner != null)
                            for (k in Reflect.fields(inner))
                                m.set(k, Std.string(Reflect.field(inner, k)));
                        engineOptionOverrides.set(pid, m);
                    }
                }
                enginePlayAs = Reflect.field(data, "enginePlayAs") != null ? data.enginePlayAs : "black";
                engineDepth = Reflect.field(data, "engineDepth") != null ? data.engineDepth : 15;
                engineTimeMs = Reflect.field(data, "engineTimeMs") != null ? data.engineTimeMs : 1000;
                builtinEvalBackend = Reflect.field(data, "builtinEvalBackend") != null ? Std.string(data.builtinEvalBackend) : "classical";
                builtinNetPath = Reflect.field(data, "builtinNetPath") != null ? Std.string(data.builtinNetPath) : "";
                builtinTablebasePath = Reflect.field(data, "builtinTablebasePath") != null ? Std.string(data.builtinTablebasePath) : "";
                engineHashMb = Reflect.field(data, "engineHashMb") != null ? data.engineHashMb : "";
                engineThreads = Reflect.field(data, "engineThreads") != null ? data.engineThreads : "";
                allowIllegalMoves = Reflect.field(data, "allowIllegalMoves") == true;
                boardLayoutId = Reflect.field(data, "boardLayoutId") != null ? data.boardLayoutId : config.BoardLayout.DEFAULT_LAYOUT_ID;
                timeControlPreset = Reflect.field(data, "timeControlPreset") != null ? data.timeControlPreset : "none";
                clockIncrementSeconds = Reflect.field(data, "clockIncrementSeconds") != null ? Std.int(data.clockIncrementSeconds) : 0;
                windowFullscreen = Reflect.field(data, "windowFullscreen") == true;
                migrateEngineProfilesIfNeeded();
            } else {
                migrateEngineProfilesIfNeeded();
            }
            #else
            var so = openfl.utils.SharedObject.getLocal("ChessSettings");
            if (so.data.uciEnginePath != null) {
                uciEnginePath = so.data.uciEnginePath;
                enginePlayAs = so.data.enginePlayAs != null ? so.data.enginePlayAs : "black";
                engineDepth = so.data.engineDepth != null ? so.data.engineDepth : 15;
                engineTimeMs = so.data.engineTimeMs != null ? so.data.engineTimeMs : 1000;
                builtinEvalBackend = so.data.builtinEvalBackend != null ? so.data.builtinEvalBackend : "classical";
                builtinNetPath = so.data.builtinNetPath != null ? so.data.builtinNetPath : "";
                builtinTablebasePath = so.data.builtinTablebasePath != null ? so.data.builtinTablebasePath : "";
                engineHashMb = so.data.engineHashMb != null ? so.data.engineHashMb : "";
                engineThreads = so.data.engineThreads != null ? so.data.engineThreads : "";
                allowIllegalMoves = so.data.allowIllegalMoves == true;
                boardLayoutId = so.data.boardLayoutId != null ? so.data.boardLayoutId : config.BoardLayout.DEFAULT_LAYOUT_ID;
                timeControlPreset = so.data.timeControlPreset != null ? so.data.timeControlPreset : "none";
                windowFullscreen = so.data.windowFullscreen == true;
            }
            #end
            normalizeBoardLayoutId();
        } catch (e:Dynamic) {
            trace("Failed to load settings: " + e);
            uciEnginePath = "";
            enginePlayAs = "black";
            engineDepth = 15;
            engineTimeMs = 1000;
            builtinEvalBackend = "classical";
            builtinNetPath = "";
            builtinTablebasePath = "";
            engineHashMb = "";
            engineThreads = "";
            boardLayoutId = BoardLayout.DEFAULT_LAYOUT_ID;
            timeControlPreset = "none";
            clockIncrementSeconds = 0;
            windowFullscreen = false;
        }
        #end
    }

    static function normalizeBoardLayoutId():Void {
        if (!BoardLayout.isKnownLayoutId(boardLayoutId))
            boardLayoutId = BoardLayout.DEFAULT_LAYOUT_ID;
    }

    /** Call after {@link CustomLayoutsStore#load} so custom ids in settings resolve correctly. */
    public static function revalidateBoardLayoutAfterCustomLayoutsLoaded():Void {
        normalizeBoardLayoutId();
    }

    public static function migrateEngineProfilesIfNeeded():Void {
        if (engineProfiles.length == 0 && uciEnginePath != null && StringTools.trim(uciEnginePath) != "") {
            var id = "default";
            var lab = Path.withoutDirectory(uciEnginePath);
            if (lab == "")
                lab = "Engine";
            engineProfiles.push({id: id, label: lab, path: uciEnginePath});
            activeEngineId = id;
        }
        if (activeEngineId == "" && engineProfiles.length > 0)
            activeEngineId = engineProfiles[0].id;
        syncUciPathFromActiveProfile();
    }

    /** Sets {@link uciEnginePath} from the active profile (for UCIManager). */
    public static function syncUciPathFromActiveProfile():Void {
        for (p in engineProfiles) {
            if (p.id == activeEngineId) {
                uciEnginePath = p.path;
                return;
            }
        }
        if (engineProfiles.length > 0) {
            activeEngineId = engineProfiles[0].id;
            uciEnginePath = engineProfiles[0].path;
        }
    }

    public static function getActiveProfile():Null<EngineProfile> {
        for (p in engineProfiles) {
            if (p.id == activeEngineId)
                return p;
        }
        return engineProfiles.length > 0 ? engineProfiles[0] : null;
    }

    public static function getMergedOptionMap():Map<String, String> {
        var m = new Map<String, String>();
        if (engineHashMb != "")
            m.set("Hash", engineHashMb);
        if (engineThreads != "")
            m.set("Threads", engineThreads);
        var om = engineOptionOverrides.get(activeEngineId);
        if (om != null)
            for (k => v in om)
                m.set(k, v);
        return m;
    }

    public static function getOptionOverride(profileId:String, name:String):String {
        var om = engineOptionOverrides.get(profileId);
        if (om == null)
            return null;
        return om.exists(name) ? om.get(name) : null;
    }

    public static function setOptionOverride(profileId:String, name:String, value:String):Void {
        if (!engineOptionOverrides.exists(profileId))
            engineOptionOverrides.set(profileId, new Map());
        engineOptionOverrides.get(profileId).set(name, value);
    }
    
    #if sys
    private static function getSettingsPath():String {
        var appData = Sys.getEnv("APPDATA");
        if (appData == null || appData == "") {
            appData = Sys.getEnv("HOME");
        }
        if (appData == null) appData = ".";
        return appData + "/Chess/settings.json";
    }
    #end
    
    /**
     * Check if UCI engine path is configured
     */
    public static function hasEnginePath():Bool {
        return uciEnginePath != null && uciEnginePath != "";
    }
}