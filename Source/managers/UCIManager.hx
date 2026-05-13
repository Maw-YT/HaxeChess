package managers;

import config.SettingsConfig;
import StringTools;
import sys.io.Process;
import haxe.Timer;
import haxe.io.Eof;
import openfl.events.EventDispatcher;
import openfl.events.Event;
import sys.thread.Thread;
import sys.thread.Mutex;

/**
 * Manages communication with UCI chess engines
 * Handles engine lifecycle, command sending, and response parsing
 */
class UCIManager extends EventDispatcher {
    private static var instance:UCIManager;
    
    private var process:Process;
    private var isEngineRunning:Bool = false;
    private var engineName:String = "";
    private var engineAuthor:String = "";
    private var isReady:Bool = false;
    private var pendingMoves:Array<String->Void> = [];
    private var currentEnginePath:String = "";
    private var readThread:Thread;
    private var outputMutex:Mutex;
    private var outputLines:Array<String>;
    private var processTimer:Timer;
    private var recentLogLines:Array<String> = [];
    private var maxRecentLogLines:Int = 400;
    
    /** Declared options from the engine (filled between "uci" and "uciok"). */
    private var engineOptionsList:Array<UciEngineOption> = [];
    
    // Events
    public static inline var ENGINE_READY:String = "engineReady";
    public static inline var ENGINE_ERROR:String = "engineError";
    public static inline var BEST_MOVE:String = "bestMove";
    public static inline var ENGINE_INFO:String = "engineInfo";
    public static inline var ENGINE_OPTIONS_READY:String = "engineOptionsReady";
    
    private var currentMoveCallback:String->Void = null;
    
    private function new() {
        super();
        outputMutex = new Mutex();
        outputLines = [];
    }
    
    public static function getInstance():UCIManager {
        if (instance == null) {
            instance = new UCIManager();
        }
        return instance;
    }
    
    /**
     * Start the UCI engine
     */
    public function startEngine(?path:String):Bool {
        if (isEngineRunning) {
            return true;
        }
        
        var enginePath = (path != null) ? path : SettingsConfig.uciEnginePath;
        if (enginePath == SettingsConfig.BUILTIN_ENGINE_PATH) {
            currentEnginePath = enginePath;
            isEngineRunning = true;
            isReady = true;
            engineName = "Built-in Engine";
            engineAuthor = "Chess GUI";
            engineOptionsList = [];
            dispatchEvent(new Event(ENGINE_OPTIONS_READY));
            dispatchEvent(new Event(ENGINE_READY));
            return true;
        }
        
        if (enginePath == null || enginePath == "") {
            trace("No engine path configured");
            dispatchEvent(new Event(ENGINE_ERROR));
            return false;
        }
        
        currentEnginePath = enginePath;
        
        try {
            // Check if file exists first
            #if sys
            if (!sys.FileSystem.exists(enginePath)) {
                trace("Engine file not found: " + enginePath);
                dispatchEvent(new Event(ENGINE_ERROR));
                return false;
            }
            
            trace("Starting engine: " + enginePath);
            
            // Change to engine directory and run
            var workingDir = haxe.io.Path.directory(enginePath);
            var exeName = haxe.io.Path.withoutDirectory(enginePath);
            
            // Save current directory
            var originalDir = Sys.getCwd();
            
            // Change to engine directory
            Sys.setCwd(workingDir);
            
            // Start process
            process = new Process(exeName);
            
            // Restore original directory
            Sys.setCwd(originalDir);
            #end
            
            isEngineRunning = true;
            isReady = false;
            
            // Clear output buffer
            outputLines = [];
            
            // Start reading thread
            startReadThread();
            
            // Start processing timer on main thread
            startProcessTimer();
            
            // Initialize UCI protocol (options stream until uciok)
            engineOptionsList = [];
            sendCommand("uci");
            
            return true;
        } catch (e:Dynamic) {
            trace("Failed to start engine: " + e);
            isEngineRunning = false;
            dispatchEvent(new Event(ENGINE_ERROR));
            return false;
        }
    }
    
    /**
     * Stop the UCI engine
     */
    public function stopEngine():Void {
        if (!isEngineRunning) return;
        if (currentEnginePath == SettingsConfig.BUILTIN_ENGINE_PATH) {
            isEngineRunning = false;
            isReady = false;
            dispatchEvent(new Event(ENGINE_ERROR));
            return;
        }

        // Drop any in-flight bestmove / pending search (must not block on reply after shutdown).
        currentMoveCallback = null;
        pendingMoves = [];

        // IMPORTANT: send stop/quit while isEngineRunning is still true — sendCommand() no-ops once false.
        // Otherwise the child never exits and readLine() blocks forever; close() can freeze on Windows.
        try {
            sendCommand("stop");
        } catch (_:Dynamic) {}
        try {
            sendCommand("quit");
        } catch (_:Dynamic) {}

        isEngineRunning = false;
        isReady = false;

        outputMutex.acquire();
        outputLines = [];
        outputMutex.release();

        if (processTimer != null) {
            processTimer.stop();
            processTimer = null;
        }

        if (process != null) {
            var p = process;
            process = null;
            try {
                #if cpp
                try {
                    p.kill();
                } catch (_:Dynamic) {}
                #end
                p.close();
            } catch (_:Dynamic) {}
        }

        dispatchEvent(new Event(ENGINE_ERROR));
    }
    
    /**
     * Restart the engine
     */
    public function restartEngine():Bool {
        stopEngine();
        return startEngine(currentEnginePath);
    }
    
    /**
     * Send a command to the engine
     */
    public function sendCommand(command:String):Void {
        if (!isEngineRunning || process == null) return;
        
        try {
            appendLogLine("> " + command);
            process.stdin.writeString(command + "\n");
            process.stdin.flush();
        } catch (e:Dynamic) {
            trace("Error sending command: " + e);
            dispatchEvent(new Event(ENGINE_ERROR));
        }
    }
    
    /**
     * Start the reading thread
     */
    private function startReadThread():Void {
        readThread = Thread.create(function() {
            while (isEngineRunning && process != null) {
                try {
                    var line = process.stdout.readLine();
                    if (line != null && line != "") {
                        outputMutex.acquire();
                        outputLines.push(line);
                        outputMutex.release();
                    }
                } catch (e:Eof) {
                    // End of stream - engine closed
                    break;
                } catch (e:Dynamic) {
                    // Some error
                    if (!isEngineRunning) break;
                    Sys.sleep(0.01); // Small sleep to prevent busy loop
                }
            }
            trace("Read thread exiting");
        });
    }
    
    /**
     * Start the processing timer on main thread
     */
    private function startProcessTimer():Void {
        processTimer = new Timer(50); // Check every 50ms
        processTimer.run = processOutputLines;
    }
    
    /**
     * Process output lines on main thread
     */
    private function processOutputLines():Void {
        if (!isEngineRunning) {
            if (processTimer != null) {
                processTimer.stop();
                processTimer = null;
            }
            return;
        }
        
        // Process all available lines
        var hadLines = true;
        while (hadLines) {
            outputMutex.acquire();
            var line = outputLines.length > 0 ? outputLines.shift() : null;
            outputMutex.release();
            
            if (line != null) {
                appendLogLine("< " + line);
                parseEngineResponse(line);
            } else {
                hadLines = false;
            }
        }
    }
    
    /**
     * Parse a response line from the engine
     */
    private function parseEngineResponse(line:String):Void {
        var parts = line.split(" ");
        var command = parts[0];
        
        switch (command) {
            case "id":
                parseId(parts);
            
            case "uciok":
                onUciOk();
            
            case "readyok":
                onReadyOk();
            
            case "bestmove":
                onBestMove(parts);
            
            case "info":
                onInfo(line);
            
            case "option":
                parseOptionLine(line);
        }
    }
    
    /**
     * Parse id command
     */
    private function parseId(parts:Array<String>):Void {
        if (parts.length < 3) return;
        
        if (parts[1] == "name") {
            engineName = parts.slice(2).join(" ");
            trace("Engine: " + engineName);
        } else if (parts[1] == "author") {
            engineAuthor = parts.slice(2).join(" ");
            trace("Author: " + engineAuthor);
        }
    }
    
    /**
     * Handle uciok response
     */
    private function onUciOk():Void {
        dispatchEvent(new Event(ENGINE_OPTIONS_READY));
        sendCommand("isready");
    }
    
    /**
     * Handle readyok response
     */
    private function onReadyOk():Void {
        isReady = true;
        dispatchEvent(new Event(ENGINE_READY));
        
        // Process any pending move requests
        processPendingMoves();
    }
    
    /**
     * Handle bestmove response
     */
    private function onBestMove(parts:Array<String>):Void {
        if (parts.length < 2) return;
        
        var move = parts[1];
        
        // Call the callback if one is waiting
        if (currentMoveCallback != null) {
            var callback = currentMoveCallback;
            currentMoveCallback = null;
            callback(move);
        }
        
        // Also dispatch event for other listeners
        dispatchEvent(new UCIEvent(BEST_MOVE, move));
    }
    
    /**
     * Handle info response
     */
    private function onInfo(line:String):Void {
        // Already emitted as a raw log line in processOutputLines().
    }

    private function appendLogLine(line:String):Void {
        trace("UCI " + line);
        recentLogLines.push(line);
        if (recentLogLines.length > maxRecentLogLines)
            recentLogLines.splice(0, recentLogLines.length - maxRecentLogLines);
        dispatchEvent(new UCIEvent(ENGINE_INFO, line));
    }
    
    private function parseOptionLine(line:String):Void {
        var t = StringTools.trim(line);
        if (!StringTools.startsWith(t, "option "))
            return;
        var afterOption = StringTools.trim(t.substr(7));
        if (!StringTools.startsWith(afterOption, "name "))
            return;
        var fromName = afterOption.substr(5);
        var typePos = fromName.indexOf(" type ");
        if (typePos < 0)
            return;
        var rawName = StringTools.trim(fromName.substr(0, typePos));
        if (rawName.length >= 2 && rawName.charAt(0) == '"')
            rawName = rawName.substr(1, rawName.length - 2);
        var afterTypeKeyword = StringTools.trim(fromName.substr(typePos + 6));
        var space = afterTypeKeyword.indexOf(" ");
        var optType = space < 0 ? afterTypeKeyword : afterTypeKeyword.substr(0, space);
        var tail = space < 0 ? "" : StringTools.trim(afterTypeKeyword.substr(space + 1));

        var opt:UciEngineOption = {
            name: rawName,
            type: optType,
            defaultValue: "",
            min: "",
            max: "",
            comboValues: []
        };
        var parts = tail.split(" ");
        var i = 0;
        while (i < parts.length) {
            var key = parts[i];
            if (key == "") {
                i++;
                continue;
            }
            switch (key) {
                case "default":
                    i++;
                    if (i < parts.length)
                        opt.defaultValue = parts[i];
                    i++;
                case "min":
                    i++;
                    if (i < parts.length)
                        opt.min = parts[i];
                    i++;
                case "max":
                    i++;
                    if (i < parts.length)
                        opt.max = parts[i];
                    i++;
                case "var":
                    i++;
                    if (i < parts.length)
                        opt.comboValues.push(parts[i]);
                    i++;
                default:
                    i++;
            }
        }
        engineOptionsList.push(opt);
    }

    public function getEngineOptions():Array<UciEngineOption> {
        return engineOptionsList.concat([]);
    }

    public function findEngineOption(name:String):Null<UciEngineOption> {
        for (o in engineOptionsList) {
            if (o.name == name)
                return o;
        }
        return null;
    }

    /**
     * Apply Hash/Threads and per-profile overrides from SettingsConfig (after engine is ready).
     */
    public function applyPersistedSpinOptions():Void {
        applyPersistedEngineOptions();
    }

    public function applyPersistedEngineOptions():Void {
        if (!isReady)
            return;
        var m = SettingsConfig.getMergedOptionMap();
        for (name => val in m) {
            var v = StringTools.trim(val);
            if (v == "")
                continue;
            setOption(name, v);
        }
    }

    /** UCI `button` options — no value. */
    public function triggerOptionButton(name:String):Void {
        sendCommand("setoption name " + name);
    }
    
    /**
     * Set an engine option (value sent as UCI `value ...`).
     */
    public function setOption(name:String, value:String):Void {
        sendCommand("setoption name " + name + " value " + value);
    }
    
    /**
     * Start a new game
     */
    public function newGame():Void {
        sendCommand("ucinewgame");
        sendCommand("isready");
    }
    
    /**
     * Set position using FEN string
     */
    public function setPosition(fen:String):Void {
        sendCommand("position fen " + fen);
    }
    
    /**
     * Set position with moves from starting position
     */
    public function setPositionFromMoves(moves:Array<String>):Void {
        sendCommand("position startpos moves " + moves.join(" "));
    }
    
    /**
     * Set position with FEN and moves
     */
    public function setPositionFenMoves(fen:String, moves:Array<String>):Void {
        var cmd = "position fen " + fen;
        if (moves.length > 0) {
            cmd += " moves " + moves.join(" ");
        }
        sendCommand(cmd);
    }
    
    /**
     * Request best move
     */
    public function getBestMove(callback:String->Void, ?depth:Int = 20, ?timeMs:Int = -1, ?wtimeMs:Int = -1, ?btimeMs:Int = -1):Void {
        if (!isReady) {
            pendingMoves.push(callback);
            return;
        }
        
        // Create a wrapper to handle the callback and cleanup
        var moveCallback:String->Void = function(move:String) {
            callback(move);
        };
        
        // Store callback for when bestmove arrives
        currentMoveCallback = moveCallback;
        
        if (wtimeMs >= 0 && btimeMs >= 0) {
            var w = Std.int(Math.max(1, wtimeMs));
            var b = Std.int(Math.max(1, btimeMs));
            sendCommand("go wtime " + w + " btime " + b);
        } else if (timeMs > 0) {
            sendCommand("go movetime " + timeMs);
        } else if (depth > 0) {
            sendCommand("go depth " + depth);
        } else {
            sendCommand("go infinite");
        }
    }
    
    /**
     * Stop current calculation
     */
    public function stopCalculation():Void {
        sendCommand("stop");
    }
    
    /**
     * Process pending move requests
     */
    private function processPendingMoves():Void {
        while (pendingMoves.length > 0) {
            var callback = pendingMoves.shift();
            // These will need to be called again with proper parameters
            // For now just notify that engine is ready
        }
    }
    
    /**
     * Check if engine is running
     */
    public function isRunning():Bool {
        return isEngineRunning;
    }
    
    /**
     * Check if engine is ready
     */
    public function isEngineReady():Bool {
        return isReady;
    }
    
    /**
     * Get engine name
     */
    public function getEngineName():String {
        return engineName;
    }
    
    /**
     * Get engine author
     */
    public function getEngineAuthor():String {
        return engineAuthor;
    }

    /**
     * Recent UCI log lines for UI replay.
     */
    public function getRecentLogLines():Array<String> {
        return recentLogLines.concat([]);
    }

    /** Emit a synthetic info line (used by built-in engine path). */
    public function emitInfoLine(line:String):Void {
        if (line == null || line == "")
            return;
        appendLogLine(line);
    }
    
    /**
     * Run a quick evaluation (just depth 1)
     */
    public function evaluatePosition(fen:String, callback:String->Void):Void {
        setPosition(fen);
        getBestMove(callback, 1);
    }
    
    /**
     * Play as a specific color
     */
    public function playAs(color:String):Void {
        // Most engines handle this automatically, but some need explicit setting
        // This is engine-specific, so we'll just note it
    }
}

/**
 * Custom event for UCI responses
 */
class UCIEvent extends Event {
    public var data:String;
    
    public function new(type:String, data:String = "") {
        super(type);
        this.data = data;
    }
}