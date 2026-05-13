package ui;

import StringTools;
import haxe.io.Path;
import openfl.Lib;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.MouseEvent;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import openfl.text.TextField;
import openfl.text.TextFormat;
import config.EngineProfile;
import config.SettingsConfig;
import managers.BuiltinEngine;
import managers.UCIManager;
import utils.BoardToFEN;
#if desktop
import lime.ui.FileDialog;
import lime.ui.FileDialogType;
#end
#if sys
import sys.FileSystem;
#end

/**
 * Engines tab: multiple UCI engine profiles, connect, logs, and full option editor.
 */
class EnginesTab extends Sprite {
    var profileDropdown:UIDropdown;
    var labelInput:UITextField;
    var pathInput:UITextField;
    var statusLabel:TextField;
    var connectBtn:UIButton;
    var disconnectBtn:UIButton;
    var testBtn:UIButton;
    var stage1Btn:UIButton;
    var evalCheckBtn:UIButton;
    var diagBtn:UIButton;
    var evalBackendBtn:UIButton;
    var engineLogField:TextField;
    var engineLogLines:Array<String> = [];
    var maxEngineLogLines:Int = 220;

    var contentW:Int;
    var viewportH:Int;
    var innerW:Int;
    var scrollLayer:Sprite;
    var scrollClip:Sprite;
    var contentH:Float = 400;
    var scrollY:Float = 0;

    var optionsModal:EngineOptionsModal;

    public function new(contentWidth:Int, viewportHeight:Int) {
        super();
        contentW = contentWidth;
        viewportH = viewportHeight;
        innerW = contentW - 8;
        build();
    }

    function build():Void {
        scrollClip = new Sprite();
        scrollClip.scrollRect = new Rectangle(0, 0, innerW, viewportH);
        scrollLayer = new Sprite();
        scrollClip.addChild(scrollLayer);
        addChild(scrollClip);

        var yPos = 10.0;
        var labelFmt = new TextFormat("Arial", 14, 0xFFFFFF, true);
        var smallFmt = new TextFormat("Arial", 11, 0xAAAAAA);
        var pathFieldW = Std.int(Math.min(480, innerW - 150));

        addLabel("Engines", labelFmt, 18, 10, yPos, 200, 30);
        yPos += 36;

        addLabel("Manage UCI engines. Pick a profile, set path, then Connect.", smallFmt, 11, 10, yPos, innerW - 10, 36);
        yPos += 40;

        addLabel("Active profile", labelFmt, 12, 10, yPos, 200, 22);
        yPos += 26;
        profileDropdown = new UIDropdown(Std.int(Math.min(400, innerW - 20)), 28);
        profileDropdown.x = 10;
        profileDropdown.y = yPos;
        profileDropdown.onChange = onProfileDropdownChange;
        scrollLayer.addChild(profileDropdown);
        var addBtn = new UIButton(90, 28, "Add", 0x37474F, 0x546E7A);
        addBtn.x = 420;
        addBtn.y = yPos;
        addBtn.setOnClick(onAddProfile);
        scrollLayer.addChild(addBtn);
        var remBtn = new UIButton(90, 28, "Remove", 0x5D4037, 0x8D6E63);
        remBtn.x = 518;
        remBtn.y = yPos;
        remBtn.setOnClick(onRemoveProfile);
        scrollLayer.addChild(remBtn);
        yPos += 36;

        addLabel("Display name", smallFmt, 11, 10, yPos, 120, 20);
        yPos += 22;
        labelInput = new UITextField(Std.int(Math.min(400, innerW - 20)), 28, "");
        labelInput.x = 10;
        labelInput.y = yPos;
        labelInput.addEventListener(Event.CHANGE, onLabelPathChange);
        scrollLayer.addChild(labelInput);
        yPos += 34;

        addLabel("Engine executable path", smallFmt, 11, 10, yPos, 240, 20);
        yPos += 22;
        pathInput = new UITextField(pathFieldW, 28, "");
        pathInput.x = 10;
        pathInput.y = yPos;
        pathInput.addEventListener(Event.CHANGE, onLabelPathChange);
        scrollLayer.addChild(pathInput);
        var browseBtn = new UIButton(100, 28, "Browse", 0x444444, 0x666666);
        browseBtn.x = 10 + pathFieldW + 10;
        browseBtn.y = yPos;
        browseBtn.setOnClick(onBrowseEngine);
        scrollLayer.addChild(browseBtn);
        var builtinBtn = new UIButton(100, 28, "Built-in", 0x37474F, 0x546E7A);
        builtinBtn.x = browseBtn.x + 108;
        builtinBtn.y = yPos;
        builtinBtn.setOnClick(onUseBuiltinEngine);
        scrollLayer.addChild(builtinBtn);
        yPos += 36;

        connectBtn = new UIButton(100, 28, "Connect", 0x2E7D32, 0x4CAF50);
        connectBtn.x = 10;
        connectBtn.y = yPos;
        connectBtn.setOnClick(onConnectEngine);
        scrollLayer.addChild(connectBtn);

        disconnectBtn = new UIButton(100, 28, "Disconnect", 0xC62828, 0xEF5350);
        disconnectBtn.x = 120;
        disconnectBtn.y = yPos;
        disconnectBtn.visible = false;
        disconnectBtn.setOnClick(onDisconnectEngine);
        scrollLayer.addChild(disconnectBtn);

        testBtn = new UIButton(100, 28, "Test", 0x1565C0, 0x42A5F5);
        testBtn.x = 230;
        testBtn.y = yPos;
        testBtn.visible = false;
        testBtn.setOnClick(onTestEngine);
        scrollLayer.addChild(testBtn);
        stage1Btn = new UIButton(150, 28, "Stage 1 checks", 0x455A64, 0x607D8B);
        stage1Btn.x = 340;
        stage1Btn.y = yPos;
        stage1Btn.visible = false;
        stage1Btn.setOnClick(onRunStage1Checks);
        scrollLayer.addChild(stage1Btn);
        evalCheckBtn = new UIButton(140, 28, "Eval checks", 0x455A64, 0x607D8B);
        evalCheckBtn.x = 500;
        evalCheckBtn.y = yPos;
        evalCheckBtn.visible = false;
        evalCheckBtn.setOnClick(onRunEvalChecks);
        scrollLayer.addChild(evalCheckBtn);
        diagBtn = new UIButton(130, 28, "Diagnostics", 0x455A64, 0x607D8B);
        diagBtn.x = 648;
        diagBtn.y = yPos;
        diagBtn.visible = false;
        diagBtn.setOnClick(onRunDiagnostics);
        scrollLayer.addChild(diagBtn);
        yPos += 36;

        evalBackendBtn = new UIButton(320, 28, "Eval backend: classical", 0x37474F, 0x546E7A);
        evalBackendBtn.x = 10;
        evalBackendBtn.y = yPos;
        evalBackendBtn.setOnClick(onToggleBuiltinEvalBackend);
        scrollLayer.addChild(evalBackendBtn);
        yPos += 34;

        statusLabel = addLabel("—", new TextFormat("Arial", 11, 0x888888), 11, 10, yPos, innerW - 10, 24);
        yPos += 30;

        addLabel("UCI log", labelFmt, 14, 10, yPos, 200, 25);
        yPos += 28;
        engineLogField = new TextField();
        engineLogField.defaultTextFormat = new TextFormat("Consolas", 10, 0xD0D0D0);
        engineLogField.multiline = true;
        engineLogField.wordWrap = false;
        engineLogField.selectable = true;
        engineLogField.border = true;
        engineLogField.borderColor = 0x3A3A3A;
        engineLogField.background = true;
        engineLogField.backgroundColor = 0x101822;
        engineLogField.width = innerW - 10;
        engineLogField.height = 140;
        engineLogField.x = 10;
        engineLogField.y = yPos;
        engineLogField.text = "";
        scrollLayer.addChild(engineLogField);
        yPos += 148;
        var clearLogBtn = new UIButton(120, 26, "Clear logs", 0x37474F, 0x546E7A);
        clearLogBtn.x = 10;
        clearLogBtn.y = yPos;
        clearLogBtn.setOnClick(function() clearEngineLogs());
        scrollLayer.addChild(clearLogBtn);
        yPos += 34;

        var optBtn = new UIButton(280, 32, "Open engine settings (all UCI options)…", 0x1565C0, 0x42A5F5);
        optBtn.x = 10;
        optBtn.y = yPos;
        optBtn.setOnClick(onOpenAllOptions);
        scrollLayer.addChild(optBtn);
        yPos += 44;

        contentH = yPos + 20;
        scrollLayer.y = 0;

        var hit = new Sprite();
        hit.graphics.beginFill(0x000000, 0.01);
        hit.graphics.drawRect(0, 0, innerW, contentH);
        hit.graphics.endFill();
        scrollLayer.addChildAt(hit, 0);

        addEventListener(Event.ADDED_TO_STAGE, onAddedToStage, false, 0, true);
        addEventListener(Event.REMOVED_FROM_STAGE, onRemovedFromStage, false, 0, true);

        refreshProfileDropdownFromConfig();
        syncFieldsFromActiveProfile();
        updateEngineUI();
    }

    function onAddedToStage(_:Event):Void {
        if (stage != null)
            stage.addEventListener(MouseEvent.MOUSE_WHEEL, onStageWheel, true, 0, true);
        var uci = UCIManager.getInstance();
        uci.addEventListener(UCIManager.ENGINE_INFO, onEngineInfoEvent);
        var recent = uci.getRecentLogLines();
        if (recent.length > 0) {
            engineLogLines = [];
            for (line in recent)
                appendEngineLog(line);
        }
    }

    function onRemovedFromStage(_:Event):Void {
        if (stage != null)
            stage.removeEventListener(MouseEvent.MOUSE_WHEEL, onStageWheel, true);
        UCIManager.getInstance().removeEventListener(UCIManager.ENGINE_INFO, onEngineInfoEvent);
    }

    function onStageWheel(e:MouseEvent):Void {
        var tl = localToGlobal(new Point(0, 0));
        var br = localToGlobal(new Point(contentW, viewportH));
        if (e.stageX < tl.x || e.stageX > br.x || e.stageY < tl.y || e.stageY > br.y)
            return;
        var mx = Math.max(0, contentH - viewportH);
        if (mx <= 0)
            return;
        scrollY = Math.max(0, Math.min(mx, scrollY - e.delta * 36));
        scrollLayer.y = -scrollY;
        e.stopPropagation();
    }

    function onEngineInfoEvent(e:Event):Void {
        if (!Std.isOfType(e, managers.UCIManager.UCIEvent))
            return;
        var ue:managers.UCIManager.UCIEvent = cast e;
        if (ue.data == null)
            return;
        appendEngineLog(Std.string(ue.data));
    }

    function appendEngineLog(line:String):Void {
        engineLogLines.push(line);
        if (engineLogLines.length > maxEngineLogLines)
            engineLogLines.splice(0, engineLogLines.length - maxEngineLogLines);
        if (engineLogField != null) {
            engineLogField.text = engineLogLines.join("\n");
            engineLogField.scrollV = engineLogField.maxScrollV;
        }
    }

    function clearEngineLogs():Void {
        engineLogLines = [];
        if (engineLogField != null)
            engineLogField.text = "";
    }

    function addLabel(text:String, fmt:TextFormat, size:Int, x:Float, y:Float, w:Float, h:Float):TextField {
        fmt.size = size;
        var tf = new TextField();
        tf.defaultTextFormat = fmt;
        tf.text = text;
        tf.selectable = false;
        tf.width = w;
        tf.height = h;
        tf.x = x;
        tf.y = y;
        scrollLayer.addChild(tf);
        return tf;
    }

    function refreshProfileDropdownFromConfig():Void {
        ensureAtLeastOneProfile();
        var ids:Array<String> = [];
        var labels:Array<String> = [];
        for (p in SettingsConfig.engineProfiles) {
            ids.push(p.id);
            labels.push(p.label != "" ? p.label : p.path);
        }
        var cur = SettingsConfig.activeEngineId;
        if (ids.indexOf(cur) < 0 && ids.length > 0)
            cur = ids[0];
        profileDropdown.setItems(ids, labels, cur);
        SettingsConfig.activeEngineId = cur;
    }

    function ensureAtLeastOneProfile():Void {
        SettingsConfig.migrateEngineProfilesIfNeeded();
        if (SettingsConfig.engineProfiles.length == 0) {
            var id = "engine1";
            SettingsConfig.engineProfiles.push({id: id, label: "Engine 1", path: ""});
            SettingsConfig.activeEngineId = id;
        }
    }

    function syncFieldsFromActiveProfile():Void {
        var p = getActiveProfile();
        if (p == null)
            return;
        labelInput.setText(p.label);
        pathInput.setText(p.path);
    }

    function getActiveProfile():Null<EngineProfile> {
        for (x in SettingsConfig.engineProfiles) {
            if (x.id == SettingsConfig.activeEngineId)
                return x;
        }
        return SettingsConfig.engineProfiles.length > 0 ? SettingsConfig.engineProfiles[0] : null;
    }

    function onProfileDropdownChange(id:String):Void {
        saveCurrentProfileEdits();
        SettingsConfig.activeEngineId = id;
        SettingsConfig.syncUciPathFromActiveProfile();
        SettingsConfig.save();
        syncFieldsFromActiveProfile();
    }

    function onLabelPathChange(_:Event):Void {
        var p = getActiveProfile();
        if (p == null)
            return;
        p.label = labelInput.getText();
        p.path = pathInput.getText();
        SettingsConfig.syncUciPathFromActiveProfile();
        SettingsConfig.save();
        refreshProfileDropdownFromConfig();
    }

    function saveCurrentProfileEdits():Void {
        var p = getActiveProfile();
        if (p == null)
            return;
        p.label = labelInput.getText();
        p.path = pathInput.getText();
        SettingsConfig.syncUciPathFromActiveProfile();
        SettingsConfig.save();
    }

    function onAddProfile():Void {
        saveCurrentProfileEdits();
        var id = "e" + Std.string(Std.int(Lib.getTimer() + Math.random() * 100000));
        var n = SettingsConfig.engineProfiles.length + 1;
        SettingsConfig.engineProfiles.push({id: id, label: "Engine " + n, path: ""});
        SettingsConfig.activeEngineId = id;
        SettingsConfig.syncUciPathFromActiveProfile();
        SettingsConfig.save();
        refreshProfileDropdownFromConfig();
        syncFieldsFromActiveProfile();
    }

    function onRemoveProfile():Void {
        if (SettingsConfig.engineProfiles.length <= 1) {
            statusLabel.text = "Cannot remove the last engine profile.";
            return;
        }
        saveCurrentProfileEdits();
        var rem = SettingsConfig.activeEngineId;
        SettingsConfig.engineProfiles = SettingsConfig.engineProfiles.filter(function(p:EngineProfile) return p.id != rem);
        SettingsConfig.engineOptionOverrides.remove(rem);
        SettingsConfig.activeEngineId = SettingsConfig.engineProfiles[0].id;
        SettingsConfig.syncUciPathFromActiveProfile();
        SettingsConfig.save();
        refreshProfileDropdownFromConfig();
        syncFieldsFromActiveProfile();
    }

    function onBrowseEngine():Void {
        #if desktop
        var dlg = new FileDialog();
        dlg.onSelect.add(function(path:String) {
            if (path == null || path == "")
                return;
            pathInput.setText(path);
            onLabelPathChange(null);
        });
        var startDir:String = null;
        #if sys
        var cur = StringTools.trim(pathInput.getText());
        if (cur != "") {
            if (FileSystem.exists(cur) && !FileSystem.isDirectory(cur)) {
                var d = Path.directory(cur);
                if (d != "" && FileSystem.exists(d) && FileSystem.isDirectory(d))
                    startDir = d;
            } else if (FileSystem.exists(cur) && FileSystem.isDirectory(cur)) {
                startDir = cur;
            }
        }
        #end
        if (!dlg.browse(FileDialogType.OPEN, null, startDir, "Select UCI chess engine")) {
            statusLabel.text = "File dialog unavailable.";
        }
        #else
        statusLabel.text = "Browse is only available in the desktop app.";
        #end
    }

    function onConnectEngine():Void {
        saveCurrentProfileEdits();
        var path = StringTools.trim(pathInput.getText());
        if (path == "") {
            statusLabel.text = "Set an engine path first.";
            return;
        }
        SettingsConfig.syncUciPathFromActiveProfile();
        SettingsConfig.save();
        statusLabel.text = "Connecting…";
        var uci = UCIManager.getInstance();
        if (!uci.startEngine(path)) {
            statusLabel.text = "Failed to start engine.";
        }
    }

    function onUseBuiltinEngine():Void {
        pathInput.setText(SettingsConfig.BUILTIN_ENGINE_PATH);
        onLabelPathChange(null);
        statusLabel.text = "Built-in engine selected.";
    }

    function onDisconnectEngine():Void {
        UCIManager.getInstance().stopEngine();
        SettingsConfig.engineConnected = false;
        updateEngineUI();
    }

    function onTestEngine():Void {
        if (SettingsConfig.uciEnginePath == SettingsConfig.BUILTIN_ENGINE_PATH) {
            var start = config.BoardLayout.getClassicLayout();
            var move = BuiltinEngine.chooseMoveFromSnapshot(start, "w", 3);
            appendEngineLog("[builtin] test from startpos -> " + (move != null && move != "" ? move : "(no move)"));
            statusLabel.text = move != null && move != "" ? "Built-in test move: " + move : "Built-in test returned no move.";
            return;
        }

        var uci = UCIManager.getInstance();
        if (!uci.isEngineReady()) {
            statusLabel.text = "Engine not ready.";
            appendEngineLog("[uci] test skipped: engine not ready");
            return;
        }
        appendEngineLog("[uci] test: position startpos, depth 5");
        uci.setPosition(BoardToFEN.startingFEN());
        uci.getBestMove(function(move:String) {
            var m = (move != null && move != "") ? move : "(no move)";
            appendEngineLog("[uci] test result -> " + m);
            statusLabel.text = "UCI test move: " + m;
        }, 5);
    }

    function onRunStage1Checks():Void {
        if (SettingsConfig.uciEnginePath != SettingsConfig.BUILTIN_ENGINE_PATH) {
            statusLabel.text = "Stage 1 checks are for built-in engine.";
            return;
        }
        appendEngineLog("== Built-in Stage 1 checks ==");
        var res = BuiltinEngine.runStage1Checks();
        for (line in res.details)
            appendEngineLog(line);
        appendEngineLog(res.passed ? "Result: PASS" : "Result: FAIL");
        statusLabel.text = res.passed ? "Stage 1 checks passed." : "Stage 1 checks failed (see log).";
    }

    function onRunEvalChecks():Void {
        if (SettingsConfig.uciEnginePath != SettingsConfig.BUILTIN_ENGINE_PATH) {
            statusLabel.text = "Eval checks are for built-in engine.";
            return;
        }
        appendEngineLog("== Built-in Eval checks ==");
        var res = BuiltinEngine.runEvalChecks();
        for (line in res.details)
            appendEngineLog(line);
        appendEngineLog(res.passed ? "Eval Result: PASS" : "Eval Result: FAIL");
        statusLabel.text = res.passed ? "Eval checks passed." : "Eval checks failed (see log).";
    }

    function onToggleBuiltinEvalBackend():Void {
        SettingsConfig.builtinEvalBackend = SettingsConfig.builtinEvalBackend == "nnue_stub" ? "classical" : "nnue_stub";
        SettingsConfig.save();
        refreshBuiltinEvalButtonLabel();
        statusLabel.text = "Built-in eval backend: " + SettingsConfig.builtinEvalBackend;
    }

    function onRunDiagnostics():Void {
        if (SettingsConfig.uciEnginePath != SettingsConfig.BUILTIN_ENGINE_PATH) {
            statusLabel.text = "Diagnostics are for built-in engine.";
            return;
        }
        appendEngineLog("== Built-in Diagnostics ==");
        var res = BuiltinEngine.runDiagnostics();
        for (line in res.details)
            appendEngineLog(line);
        appendEngineLog(res.passed ? "Diagnostics: PASS" : "Diagnostics: FAIL");
        statusLabel.text = res.passed ? "Diagnostics passed." : "Diagnostics failed (see log).";
    }

    function refreshBuiltinEvalButtonLabel():Void {
        if (evalBackendBtn == null)
            return;
        evalBackendBtn.setLabel("Eval backend: " + SettingsConfig.builtinEvalBackend);
    }

    function onOpenAllOptions():Void {
        var uci = UCIManager.getInstance();
        if (!uci.isEngineReady() || !SettingsConfig.engineConnected) {
            statusLabel.text = "Connect an engine first.";
            return;
        }
        var st = Lib.current.stage;
        if (st == null)
            return;
        if (optionsModal != null && optionsModal.parent != null)
            optionsModal.parent.removeChild(optionsModal);
        optionsModal = new EngineOptionsModal();
        optionsModal.open(Std.int(st.stageWidth), Std.int(st.stageHeight), SettingsConfig.activeEngineId, uci, function() {
            optionsModal = null;
        });
        st.addChild(optionsModal);
    }

    public function updateEngineUI():Void {
        var connected = SettingsConfig.engineConnected;
        if (connectBtn != null)
            connectBtn.visible = !connected;
        if (disconnectBtn != null)
            disconnectBtn.visible = connected;
        if (testBtn != null)
            testBtn.visible = connected;
        if (stage1Btn != null)
            stage1Btn.visible = connected && SettingsConfig.uciEnginePath == SettingsConfig.BUILTIN_ENGINE_PATH;
        if (evalCheckBtn != null)
            evalCheckBtn.visible = connected && SettingsConfig.uciEnginePath == SettingsConfig.BUILTIN_ENGINE_PATH;
        if (diagBtn != null)
            diagBtn.visible = connected && SettingsConfig.uciEnginePath == SettingsConfig.BUILTIN_ENGINE_PATH;
        if (evalBackendBtn != null)
            evalBackendBtn.visible = SettingsConfig.uciEnginePath == SettingsConfig.BUILTIN_ENGINE_PATH;
        refreshBuiltinEvalButtonLabel();
        if (statusLabel == null)
            return;
        if (connected) {
            statusLabel.defaultTextFormat = new TextFormat("Arial", 11, 0x4CAF50);
            statusLabel.text = "Connected: " + SettingsConfig.engineName;
        } else if (SettingsConfig.hasEnginePath()) {
            statusLabel.defaultTextFormat = new TextFormat("Arial", 11, 0xAAAAAA);
            statusLabel.text = "Disconnected. Path: " + SettingsConfig.uciEnginePath;
        } else {
            statusLabel.defaultTextFormat = new TextFormat("Arial", 11, 0x888888);
            statusLabel.text = "No engine path for this profile.";
        }
    }

    public function refreshSpinHints():Void {
        /* Hash/Threads are edited in the full options dialog. */
    }

    public function syncInputsFromConfig():Void {
        SettingsConfig.migrateEngineProfilesIfNeeded();
        refreshProfileDropdownFromConfig();
        syncFieldsFromActiveProfile();
        updateEngineUI();
    }
}
