package managers;

import openfl.events.Event;
import openfl.media.Sound;
import openfl.media.SoundChannel;
import openfl.media.SoundTransform;
import openfl.media.SoundMixer;
import openfl.utils.Assets as OpenFLAssets;
#if lime
import lime.media.AudioManager;
import lime.media.AudioBuffer;
import lime.utils.AssetType;
import lime.utils.Assets as LimeAssets;
import lime.utils.Bytes as LimeBytes;
#end
#if sys
import haxe.io.Path;
import lime.system.System;
import sys.FileSystem;
import Sys;
#end

/**
 * Manages all game sound effects
 * Singleton pattern for easy access throughout the game
 */
class SoundManager {
    private static var instance:SoundManager;
    private static var loggedLoadFailures:Map<String, Bool> = new Map();

    private var sounds:Map<String, Sound>;
    private var enabled:Bool = true;
    private var volume:Float = 0.7;
    private var triedReload:Bool = false;

    public static inline var MOVE_SELF:String = "move-self";
    public static inline var CAPTURE:String = "capture";
    public static inline var CASTLE:String = "castle";
    public static inline var MOVE_CHECK:String = "move-check";
    public static inline var PROMOTE:String = "promote";
    public static inline var GAME_START:String = "game-start";
    public static inline var GAME_END:String = "game-end";

    private function new() {
        sounds = new Map();
        SoundMixer.soundTransform = new SoundTransform(1, 0);
        loadSounds();
        haxe.Timer.delay(function() {
            if (sounds.get(MOVE_SELF) == null)
                loadSounds();
        }, 0);
    }

    public static function getInstance():SoundManager {
        if (instance == null) {
            instance = new SoundManager();
        }
        return instance;
    }

    private function loadSounds():Void {
        loadOne(MOVE_SELF, "move-self");
        loadOne(CAPTURE, "capture");
        loadOne(CASTLE, "castle");
        loadOne(MOVE_CHECK, "move-check");
        loadOne(PROMOTE, "promote");
        loadOne(GAME_START, "game-start");
        loadOne(GAME_END, "game-end");
    }

    private function assetIdCandidates(relPath:String):Array<String> {
        return [relPath, "default:" + relPath];
    }

    private function warnOnce(key:String, message:String):Void {
        if (loggedLoadFailures.exists(key))
            return;
        loggedLoadFailures.set(key, true);
        trace(message);
    }

    #if lime
    private function limeBufferFor(relPath:String):AudioBuffer {
        for (aid in assetIdCandidates(relPath)) {
            var buf:Dynamic = null;
            try {
                buf = LimeAssets.getAsset(aid, AssetType.SOUND, false);
            } catch (_:Dynamic) {}
            if (buf == null) {
                try {
                    buf = LimeAssets.getAsset(aid, AssetType.MUSIC, false);
                } catch (_:Dynamic) {}
            }
            if (buf != null)
                return cast buf;
        }
        return null;
    }

    private function bufferFromAbsolutePath(fullPath:String):AudioBuffer {
        if (fullPath == null || fullPath == "")
            return null;
        var buf:AudioBuffer = null;
        try {
            buf = AudioBuffer.fromFile(fullPath);
        } catch (_:Dynamic) {}
        if (buf != null)
            return buf;
        #if sys
        if (!FileSystem.exists(fullPath))
            return null;
        try {
            var bytes = LimeBytes.fromFile(fullPath);
            if (bytes != null) {
                buf = AudioBuffer.fromBytes(bytes);
                if (buf != null)
                    return buf;
            }
        } catch (_:Dynamic) {}
        #end
        return null;
    }
    #end

    #if sys
    private function pushUnique(list:Array<String>, path:String):Void {
        if (path == null || path == "")
            return;
        path = Path.normalize(StringTools.replace(path, "\\", "/"));
        for (p in list)
            if (p == path)
                return;
        list.push(path);
    }

    private function diskPathCandidates(relPath:String):Array<String> {
        var rel = StringTools.replace(relPath, "\\", "/");
        var out:Array<String> = [];
        #if lime
        for (aid in assetIdCandidates(rel)) {
            try {
                if (LimeAssets.exists(aid, AssetType.SOUND) || LimeAssets.exists(aid, AssetType.MUSIC)) {
                    var p = LimeAssets.getPath(aid);
                    pushUnique(out, p);
                }
            } catch (_:Dynamic) {}
        }
        #end
        try {
            pushUnique(out, Path.normalize(System.applicationDirectory + "/" + rel));
        } catch (_:Dynamic) {}
        try {
            pushUnique(out, Path.normalize(Path.directory(Sys.programPath()) + "/" + rel));
        } catch (_:Dynamic) {}
        try {
            pushUnique(out, Path.normalize(Sys.getCwd() + "/" + rel));
        } catch (_:Dynamic) {}
        return out;
    }

    private function soundFromDisk(relPath:String):Sound {
        #if lime
        for (full in diskPathCandidates(relPath)) {
            if (!FileSystem.exists(full))
                continue;
            var buf = bufferFromAbsolutePath(full);
            if (buf != null) {
                try {
                    return Sound.fromAudioBuffer(buf);
                } catch (_:Dynamic) {}
            }
        }
        #end
        return null;
    }
    #end

    private function tryLoadRelPath(relPath:String):Sound {
        var sound:Sound = null;

        #if lime
        try {
            var buf = limeBufferFor(relPath);
            if (buf != null)
                sound = Sound.fromAudioBuffer(buf);
        } catch (_:Dynamic) {}

        if (sound == null) {
            for (aid in assetIdCandidates(relPath)) {
                try {
                    sound = OpenFLAssets.getSound(aid);
                    if (sound != null)
                        break;
                } catch (_:Dynamic) {}
            }
        }

        if (sound == null) {
            for (aid in assetIdCandidates(relPath)) {
                if (!OpenFLAssets.exists(aid))
                    continue;
                try {
                    var fp = OpenFLAssets.getPath(aid);
                    if (fp != null && fp != "") {
                        var ab = bufferFromAbsolutePath(fp);
                        if (ab != null)
                            sound = Sound.fromAudioBuffer(ab);
                        if (sound != null)
                            break;
                    }
                } catch (_:Dynamic) {}
            }
        }
        #end

        #if sys
        if (sound == null)
            sound = soundFromDisk(relPath);
        #end

        return sound;
    }

    /**
     * Tries assets/{base}.ogg first (native), then .mp3 (e.g. HTML5).
     */
    private function loadOne(id:String, baseName:String):Void {
        for (ext in ["ogg", "mp3"]) {
            var rel = "assets/" + baseName + "." + ext;
            var s = tryLoadRelPath(rel);
            if (s != null) {
                sounds.set(id, s);
                return;
            }
        }
        warnOnce(id, 'SoundManager: could not load "$baseName" (tried .ogg and .mp3)');
    }

    public function play(soundId:String):Void {
        playReturning(soundId);
    }

    /** Starts `soundId`; returns the channel so callers can wait for `Event.SOUND_COMPLETE`. */
    public function playReturning(soundId:String):SoundChannel {
        if (!enabled)
            return null;

        #if lime
        AudioManager.resume();
        #end

        var sound = sounds.get(soundId);
        if (sound == null) {
            if (!triedReload) {
                triedReload = true;
                loadSounds();
                sound = sounds.get(soundId);
            }
            if (sound == null)
                return null;
        }

        try {
            var xf = new SoundTransform(volume, 0);
            var channel:SoundChannel = sound.play(0, 0, xf);
            if (channel == null)
                trace("SoundManager: play() returned null for " + soundId);
            return channel;
        } catch (e:Dynamic) {
            trace("SoundManager: play failed: " + soundId + " " + e);
            return null;
        }
    }

    public function playMove(isCheck:Bool = false):SoundChannel {
        return playReturning(isCheck ? MOVE_CHECK : MOVE_SELF);
    }

    public function playCapture():SoundChannel {
        return playReturning(CAPTURE);
    }

    public function playCastle():SoundChannel {
        return playReturning(CASTLE);
    }

    public function playPromote():SoundChannel {
        return playReturning(PROMOTE);
    }

    /**
     * Call in the same frame as the move SFX: `game-end` overlaps the move sound if the game ended;
     * `game-start` runs only after the move (or castle / promote) clip finishes when this is the first half-move.
     */
    public function playGameEndWithPrimaryMove(primaryMoveSoundChannel:SoundChannel, historyLength:Int, gameState:String):Void {
        if (isTerminalGameOutcome(gameState))
            play(GAME_END);
        if (historyLength != 1)
            return;
        if (primaryMoveSoundChannel != null) {
            function onPrimaryDone(_:Event):Void {
                primaryMoveSoundChannel.removeEventListener(Event.SOUND_COMPLETE, onPrimaryDone);
                play(GAME_START);
            }
            primaryMoveSoundChannel.addEventListener(Event.SOUND_COMPLETE, onPrimaryDone);
        } else {
            play(GAME_START);
        }
    }

    private function isTerminalGameOutcome(gs:String):Bool {
        return gs == "checkmate" || gs == "stalemate" || gs == "draw_repetition" || gs == "draw_material"
            || gs == "draw_no_royals" || gs == "win_white" || gs == "win_black";
    }

    public function setEnabled(enabled:Bool):Void {
        this.enabled = enabled;
    }

    public function isEnabled():Bool {
        return enabled;
    }

    public function setVolume(volume:Float):Void {
        this.volume = Math.max(0, Math.min(1, volume));
    }

    public function getVolume():Float {
        return volume;
    }
}
