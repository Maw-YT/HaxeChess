package ui;

import StringTools;
import openfl.Lib;
import openfl.display.Bitmap;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.MouseEvent;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.utils.Assets;
import config.BoardLayout;
import config.CustomLayoutsStore;
import config.GameConfig;
import config.SettingsConfig;
import config.PieceCatalog;
import utils.BoardUtils;

/**
 * Build arbitrary board sizes, place pieces, name and save layouts for the Settings dropdown.
 * Board on the left; toolbox and options in a right-side panel.
 */
class LayoutMakerTab extends Sprite {
    static inline var MAIN_SPLIT_Y:Float = 86;

    public var onLayoutsChanged:Void->Void;

    var viewportH:Int;
    var innerW:Int;
    /** Right panel width (grows with window so the toolbox can use more columns). */
    var rightPanelWidth:Int = 272;
    var toolboxScrollClip:Sprite = null;
    var toolboxContentPixelHeight:Float = 0;

    var colsField:UITextField;
    var rowsField:UITextField;
    var nameField:UITextField;
    var loadDropdown:UIDropdown;
    var rightPanel:Sprite;

    var boardData:Array<Array<String>>;
    var cols:Int = 8;
    var rows:Int = 8;
    var tileSize:Int = 36;

    var boardViewport:BoardViewPort;
    var panelBg:Shape;
    var headerTitleTf:TextField;
    var headerBlurbTf:TextField;
    /** First right-panel child index to remove when rebuilding the toolbox block (from "Toolbox" label onward). */
    var firstToolboxChildIndex:Int = 0;
    /** Y in `rightPanel` where the toolbox title row starts (after save/delete row). */
    var toolboxBlockStartPy:Float = 0;
    var saveLayoutBtn:UIButton;
    var saveAsNewBtn:UIButton;
    var deleteSavedBtn:UIButton;
    var boardBg:Shape;
    var piecesLayer:Sprite;
    var highlightLayer:Shape;

    var boardLeft:Float = 10;
    var boardTop:Float = MAIN_SPLIT_Y;

    /** Board area width reserved for the grid (left column). */
    var boardAreaW:Int = 400;

    /** Toolbox + board: selected piece id, eraser, or "". */
    var selectedTool:String = "";

    var editingCustomId:String = null;

    var dragBmp:Bitmap = null;
    var dragFromBoard:Null<{r:Int, c:Int, id:String}>;
    var stageMoveHandler:MouseEvent->Void;
    var stageUpHandler:MouseEvent->Void;
    var toolboxProbeMove:MouseEvent->Void;
    var toolboxProbeUp:MouseEvent->Void;

    /** Line paint: snapshot at stroke start; Bresenham from start to current. */
    var linePaintSnapshot:Array<Array<String>> = null;
    var linePaintStartC:Int = 0;
    var linePaintStartR:Int = 0;
    var linePaintFill:String = "";
    var linePaintMove:MouseEvent->Void;
    var linePaintUp:MouseEvent->Void;
    /** When true, line paint ends on `RIGHT_MOUSE_UP` instead of `MOUSE_UP`. */
    var linePaintEndOnRight:Bool = false;

    public function new(contentWidth:Int, viewportHeight:Int) {
        super();
        this.viewportH = viewportHeight;
        this.innerW = contentWidth - 20;
        rightPanelWidth = Std.int(Math.min(520, Math.max(240, Math.floor(innerW * 0.34))));
        boardAreaW = Std.int(Math.max(160, innerW - rightPanelWidth - 28));
        boardData = emptyBoard(cols, rows);

        var titleFmt = new TextFormat("Arial", 16, 0xFFFFFF, true);
        var smallFmt = new TextFormat("Arial", 10, 0xAAAAAA);

        headerTitleTf = addLabel("Layout maker", titleFmt, 16, 10, 10, innerW, 24);
        headerBlurbTf = addLabel(
            "Board on the left (up to 32×32). Mouse wheel zooms the board; middle-drag or Alt+left-drag pans. Right panel: pieces and options. Pick a piece tool, then click or drag on the board to paint a straight line of that piece. Right-click or right-drag on the board to clear squares (and clear the selected tool). Drag pieces when no tool is selected.",
            smallFmt,
            10,
            10,
            38,
            innerW,
            44
        );

        boardTop = MAIN_SPLIT_Y;
        var clipH = viewportH - Std.int(boardTop) - 8;
        if (clipH < 80)
            clipH = 80;
        boardViewport = new BoardViewPort(boardAreaW, clipH);
        boardViewport.x = boardLeft;
        boardViewport.y = boardTop;
        addChild(boardViewport);

        var bw = boardViewport.world;
        boardBg = new Shape();
        bw.addChild(boardBg);

        highlightLayer = new Shape();
        bw.addChild(highlightLayer);

        piecesLayer = new Sprite();
        bw.addChild(piecesLayer);

        bw.addEventListener(MouseEvent.MOUSE_DOWN, onBoardMouseDown, false, 0, true);
        bw.addEventListener(MouseEvent.RIGHT_MOUSE_DOWN, onBoardRightMouseDown, false, 0, true);

        rightPanel = new Sprite();
        rightPanel.x = boardLeft + boardAreaW + 12;
        rightPanel.y = MAIN_SPLIT_Y;
        var panelH = viewportH - Std.int(MAIN_SPLIT_Y) - 10;
        if (panelH < 200)
            panelH = 200;
        panelBg = new Shape();
        panelBg.graphics.beginFill(0x242428);
        panelBg.graphics.lineStyle(1, 0x454545);
        panelBg.graphics.drawRoundRect(0, 0, rightPanelWidth, panelH, 10, 10);
        panelBg.graphics.endFill();
        rightPanel.addChild(panelBg);

        var bodyFmt = new TextFormat("Arial", 11, 0xCCCCCC);
        var py:Float = 12;
        addLabelTo(rightPanel, "Columns", bodyFmt, 12, py, 56, 18);
        colsField = new UITextField(52, 24, "");
        colsField.x = 72;
        colsField.y = py - 2;
        colsField.setText("8");
        rightPanel.addChild(colsField);

        addLabelTo(rightPanel, "Rows", bodyFmt, 132, py, 40, 18);
        rowsField = new UITextField(52, 24, "");
        rowsField.x = 170;
        rowsField.y = py - 2;
        rowsField.setText("8");
        rightPanel.addChild(rowsField);
        py += 32;

        var applyBtn = new UIButton(100, 26, "Apply size", 0x37474F, 0x546E7A);
        applyBtn.x = 12;
        applyBtn.y = py;
        applyBtn.setOnClick(onApplySizeClick);
        rightPanel.addChild(applyBtn);

        var clearBtn = new UIButton(100, 26, "Clear board", 0x5D4037, 0x8D6E63);
        clearBtn.x = 118;
        clearBtn.y = py;
        clearBtn.setOnClick(function() {
            clearBoardData();
            refreshBoardGraphics();
        });
        rightPanel.addChild(clearBtn);
        py += 34;

        addLabelTo(rightPanel, "Load into editor", bodyFmt, 12, py, 200, 18);
        py += 20;
        var ddW = rightPanelWidth - 24;
        loadDropdown = new UIDropdown(ddW, 26);
        loadDropdown.x = 12;
        loadDropdown.y = py;
        refreshLoadDropdown(null);
        loadDropdown.onChange = onLoadLayoutChoice;
        rightPanel.addChild(loadDropdown);
        py += 36;

        addLabelTo(rightPanel, "Layout name", bodyFmt, 12, py, 200, 18);
        py += 20;
        nameField = new UITextField(ddW, 26, "My layout");
        nameField.x = 12;
        nameField.y = py;
        rightPanel.addChild(nameField);
        py += 32;

        var btnHalf = Std.int((ddW - 8) / 2);
        var btnSecond = ddW - 8 - btnHalf;
        saveLayoutBtn = new UIButton(btnHalf, 28, "Save layout", 0x1B5E20, 0x43A047);
        saveLayoutBtn.x = 12;
        saveLayoutBtn.y = py;
        saveLayoutBtn.setOnClick(onSaveClick);
        rightPanel.addChild(saveLayoutBtn);

        saveAsNewBtn = new UIButton(btnSecond, 28, "Save as new", 0x2E7D32, 0x66BB6A);
        saveAsNewBtn.x = 12 + btnHalf + 8;
        saveAsNewBtn.y = py;
        saveAsNewBtn.setOnClick(onSaveAsNewClick);
        rightPanel.addChild(saveAsNewBtn);
        py += 34;

        deleteSavedBtn = new UIButton(ddW, 28, "Delete saved", 0xB71C1C, 0xE53935);
        deleteSavedBtn.x = 12;
        deleteSavedBtn.y = py;
        deleteSavedBtn.setOnClick(onDeleteClick);
        rightPanel.addChild(deleteSavedBtn);
        py += 40;

        toolboxBlockStartPy = py;
        firstToolboxChildIndex = rightPanel.numChildren;
        addLabelTo(rightPanel, "Toolbox", new TextFormat("Arial", 12, 0xFFFFFF, true), 12, py, 200, 20);
        py += 24;
        addLabelTo(
            rightPanel,
            "Click piece to select. Drag from toolbox to place one. On board: click or hold-drag for a line.",
            new TextFormat("Arial", 9, 0x999999),
            12,
            py,
            rightPanelWidth - 16,
            40
        );
        py += 44;

        var toolboxViewportH = panelH - py - 14;
        if (toolboxViewportH < 96)
            toolboxViewportH = 96;
        buildToolboxInPanel(rightPanel, 12, py, toolboxViewportH);

        addChild(rightPanel);

        addEventListener(Event.REMOVED_FROM_STAGE, onRemoved);

        refreshBoardGraphics();
    }

    function addLabelTo(parent:Sprite, text:String, fmt:TextFormat, x:Float, y:Float, w:Float, h:Float):TextField {
        var tf = new TextField();
        tf.defaultTextFormat = fmt;
        tf.text = text;
        tf.x = x;
        tf.y = y;
        tf.width = w;
        tf.height = h;
        tf.selectable = false;
        tf.mouseEnabled = false;
        parent.addChild(tf);
        return tf;
    }

    function onRemoved(_:Event):Void {
        cancelActiveDrag();
        if (toolboxScrollClip != null) {
            toolboxScrollClip.removeEventListener(MouseEvent.MOUSE_WHEEL, onToolboxWheel);
            toolboxScrollClip = null;
        }
    }

    function onToolboxWheel(e:MouseEvent):Void {
        if (toolboxScrollClip == null)
            return;
        var r = toolboxScrollClip.scrollRect;
        if (r == null)
            return;
        var maxScroll = Math.max(0, toolboxContentPixelHeight - r.height);
        if (maxScroll <= 0)
            return;
        var step = e.delta > 0 ? -32 : 32;
        var ny = r.y + step;
        if (ny < 0)
            ny = 0;
        if (ny > maxScroll)
            ny = maxScroll;
        toolboxScrollClip.scrollRect = new Rectangle(0, ny, r.width, r.height);
        e.stopPropagation();
    }

    /**
     * Piece toolbox: column count follows panel width and remaining vertical space; scrolls when needed.
     */
    function buildToolboxInPanel(panel:Sprite, x0:Float, y0:Float, toolboxViewportH:Float):Void {
        if (toolboxScrollClip != null) {
            toolboxScrollClip.removeEventListener(MouseEvent.MOUSE_WHEEL, onToolboxWheel);
            toolboxScrollClip = null;
        }

        var cell = 40;
        var gap = 5;
        var colW = cell + gap;
        var rowH = cell + gap;
        var usableW = rightPanelWidth - 2 * x0;
        if (usableW < colW * 2 + 4)
            usableW = colW * 2 + 4;

        var tw = PieceCatalog.toolboxPieceIds("w");
        var tb = PieceCatalog.toolboxPieceIds("b");
        var nItems = tw.length + tb.length;
        var maxCols = Std.int(Math.max(2, Math.floor((usableW - 2) / colW)));

        var availH = toolboxViewportH;
        var numCols = maxCols;
        var c = maxCols;
        while (c >= 2) {
            var rowsNeeded = Std.int(Math.ceil(nItems / c));
            if (rowsNeeded * rowH <= availH) {
                numCols = c;
                break;
            }
            c--;
        }
        if (c < 2)
            numCols = maxCols;

        var rowsTotal = Std.int(Math.ceil(nItems / numCols));
        var contentH = rowsTotal * rowH;
        toolboxContentPixelHeight = contentH;

        var viewH = contentH <= availH ? contentH : availH;
        if (viewH < 72)
            viewH = Math.min(availH, 72);

        var clip = new Sprite();
        clip.x = x0;
        clip.y = y0;
        clip.scrollRect = new Rectangle(0, 0, usableW, viewH);
        clip.mouseEnabled = true;
        clip.mouseChildren = true;

        var content = new Sprite();
        clip.addChild(content);

        var idx = 0;
        function placePiece(pid:String):Void {
            var col = idx % numCols;
            var row = Std.int(idx / numCols);
            idx++;
            addToolCell(content, pid, col * colW, row * rowH, cell);
        }
        for (p in tw)
            placePiece(p);
        for (p in tb)
            placePiece(p);

        if (contentH > viewH + 0.5) {
            toolboxScrollClip = clip;
            clip.addEventListener(MouseEvent.MOUSE_WHEEL, onToolboxWheel, false, 0, true);
        } else {
            toolboxScrollClip = null;
        }

        var rim = new Sprite();
        rim.mouseEnabled = false;
        rim.mouseChildren = false;
        rim.graphics.lineStyle(1, 0x555555);
        rim.graphics.drawRect(0, 0, usableW, viewH);
        clip.addChild(rim);

        panel.addChild(clip);
    }

    function addToolCell(parent:Sprite, pieceId:String, x:Float, y:Float, cell:Int):Void {
        var box = new Sprite();
        box.x = x;
        box.y = y;
        var bg = new Shape();
        bg.graphics.beginFill(0x2E2E32);
        bg.graphics.lineStyle(1, 0x555555);
        bg.graphics.drawRect(0, 0, cell, cell);
        bg.graphics.endFill();
        box.addChild(bg);
        var bmp = pieceBitmap(pieceId, cell - 4);
        bmp.x = 2;
        bmp.y = 2;
        box.addChild(bmp);
        box.buttonMode = true;
        box.useHandCursor = true;
        var pid = pieceId;
        box.addEventListener(MouseEvent.MOUSE_DOWN, function(e:MouseEvent) {
            e.stopPropagation();
            var st = Lib.current.stage;
            var sx = e.stageX;
            var sy = e.stageY;
            var dragged = false;
            function move(e2:MouseEvent):Void {
                if (!dragged && (Math.abs(e2.stageX - sx) > 4 || Math.abs(e2.stageY - sy) > 4)) {
                    dragged = true;
                    if (toolboxProbeMove != null)
                        st.removeEventListener(MouseEvent.MOUSE_MOVE, toolboxProbeMove);
                    if (toolboxProbeUp != null)
                        st.removeEventListener(MouseEvent.MOUSE_UP, toolboxProbeUp);
                    toolboxProbeMove = null;
                    toolboxProbeUp = null;
                    startToolboxDrag(pid, e2.stageX, e2.stageY);
                }
            }
            function up(_:MouseEvent):Void {
                st.removeEventListener(MouseEvent.MOUSE_MOVE, move);
                st.removeEventListener(MouseEvent.MOUSE_UP, up);
                toolboxProbeMove = null;
                toolboxProbeUp = null;
                if (!dragged)
                    selectTool(pid);
            }
            toolboxProbeMove = move;
            toolboxProbeUp = up;
            st.addEventListener(MouseEvent.MOUSE_MOVE, move);
            st.addEventListener(MouseEvent.MOUSE_UP, up);
        });
        parent.addChild(box);
    }

    function selectTool(pid:String):Void {
        selectedTool = pid;
    }

    function onApplySizeClick():Void {
        var c = Std.parseInt(StringTools.trim(colsField.getText()));
        var r = Std.parseInt(StringTools.trim(rowsField.getText()));
        if (c == null || r == null)
            return;
        c = clamp(c, 3, 32);
        r = clamp(r, 3, 32);
        colsField.setText(Std.string(c));
        rowsField.setText(Std.string(r));
        resizePreserving(c, r);
        refreshBoardGraphics();
    }

    function clamp(v:Int, lo:Int, hi:Int):Int {
        if (v < lo)
            return lo;
        if (v > hi)
            return hi;
        return v;
    }

    function resizePreserving(newCols:Int, newRows:Int):Void {
        var old = boardData;
        var oc = cols;
        var or = rows;
        cols = newCols;
        rows = newRows;
        var next = emptyBoard(cols, rows);
        for (r in 0...rows) {
            for (c in 0...cols) {
                if (r < or && c < oc && old != null && r < old.length) {
                    var row = old[r];
                    if (row != null && c < row.length)
                        next[r][c] = row[c];
                }
            }
        }
        boardData = next;
    }

    function emptyBoard(w:Int, h:Int):Array<Array<String>> {
        return [for (r in 0...h) [for (c in 0...w) ""]];
    }

    function clearBoardData():Void {
        boardData = emptyBoard(cols, rows);
    }

    function computeTileSize():Int {
        var maxBoardPxW = boardAreaW - 2;
        var maxBoardPxH = viewportH - Std.int(boardTop) - 10;
        if (maxBoardPxW < 48)
            maxBoardPxW = 48;
        if (maxBoardPxH < 48)
            maxBoardPxH = 48;
        var maxBoardPx = maxBoardPxW < maxBoardPxH ? maxBoardPxW : maxBoardPxH;
        var m = cols > rows ? cols : rows;
        var t = Std.int(Math.floor(maxBoardPx / m));
        if (t < 12)
            t = 12;
        if (t > 128)
            t = 128;
        return t;
    }

    function refreshBoardGraphics():Void {
        tileSize = computeTileSize();
        boardBg.graphics.clear();
        for (r in 0...rows) {
            for (c in 0...cols) {
                var light = ((r + c) % 2) == 0;
                boardBg.graphics.beginFill(light ? GameConfig.COLOR_LIGHT : GameConfig.COLOR_DARK);
                boardBg.graphics.drawRect(c * tileSize, r * tileSize, tileSize, tileSize);
            }
        }
        highlightLayer.graphics.clear();
        piecesLayer.removeChildren();
        for (r in 0...rows) {
            for (c in 0...cols) {
                var id = boardData[r][c];
                if (id != null && id != "") {
                    var bmp = pieceBitmap(id, tileSize - 2);
                    bmp.x = c * tileSize + 1;
                    bmp.y = r * tileSize + 1;
                    piecesLayer.addChild(bmp);
                }
            }
        }
        if (boardViewport != null) {
            var clipH = viewportH - Std.int(boardTop) - 8;
            if (clipH < 80)
                clipH = 80;
            boardViewport.setClipSize(boardAreaW, clipH);
            boardViewport.resetView();
        }
    }

    function pieceBitmap(id:String, px:Int):Bitmap {
        var path = GameConfig.ASSETS_PATH + id + ".png";
        if (!Assets.exists(path))
            path = GameConfig.ASSETS_PATH + GameConfig.MISSING_ASSET;
        var bmp = new Bitmap(Assets.getBitmapData(path));
        bmp.smoothing = true;
        var bd = bmp.bitmapData;
        if (bd != null && bd.width > 0) {
            bmp.scaleX = px / bd.width;
            bmp.scaleY = px / bd.height;
        }
        return bmp;
    }

    function cellFromStage(stageX:Float, stageY:Float):Null<{r:Int, c:Int}> {
        if (boardViewport == null)
            return null;
        var lp = boardViewport.world.globalToLocal(new Point(stageX, stageY));
        var c = Std.int(Math.floor(lp.x / tileSize));
        var r = Std.int(Math.floor(lp.y / tileSize));
        if (c < 0 || r < 0 || c >= cols || r >= rows)
            return null;
        return {r: r, c: c};
    }

    function onBoardMouseDown(e:MouseEvent):Void {
        var cell = cellFromStage(e.stageX, e.stageY);
        if (cell == null)
            return;
        var r = cell.r;
        var c = cell.c;

        if (selectedTool != null && selectedTool != "") {
            beginLinePaint(r, c, selectedTool);
            return;
        }

        var pid = boardData[r][c];
        if (pid != null && pid != "") {
            startBoardDrag(r, c, pid, e.stageX, e.stageY);
        }
    }

    function onBoardRightMouseDown(e:MouseEvent):Void {
        e.stopPropagation();
        selectTool("");
        var cell = cellFromStage(e.stageX, e.stageY);
        if (cell == null)
            return;
        beginLinePaint(cell.r, cell.c, "", true);
    }

    function beginLinePaint(r:Int, c:Int, fill:String, ?endOnRightMouseUp:Bool = false):Void {
        cancelActiveDrag();
        linePaintEndOnRight = endOnRightMouseUp;
        linePaintSnapshot = BoardUtils.copyBoard(boardData);
        linePaintStartR = r;
        linePaintStartC = c;
        linePaintFill = fill;
        applyLineToBoard(linePaintStartC, linePaintStartR, c, r);
        refreshBoardGraphics();

        var st = Lib.current.stage;
        linePaintMove = function(e2:MouseEvent):Void {
            var cl = cellFromStage(e2.stageX, e2.stageY);
            if (cl == null)
                return;
            boardData = BoardUtils.copyBoard(linePaintSnapshot);
            applyLineToBoard(linePaintStartC, linePaintStartR, cl.c, cl.r);
            refreshBoardGraphics();
        };
        linePaintUp = function(_:MouseEvent):Void {
            endLinePaint(true);
        };
        st.addEventListener(MouseEvent.MOUSE_MOVE, linePaintMove);
        if (linePaintEndOnRight)
            st.addEventListener(MouseEvent.RIGHT_MOUSE_UP, linePaintUp);
        else
            st.addEventListener(MouseEvent.MOUSE_UP, linePaintUp);
    }

    function endLinePaint(commit:Bool):Void {
        var st = Lib.current.stage;
        if (linePaintMove != null) {
            st.removeEventListener(MouseEvent.MOUSE_MOVE, linePaintMove);
            linePaintMove = null;
        }
        if (linePaintUp != null) {
            var upWasRight = linePaintEndOnRight;
            if (upWasRight)
                st.removeEventListener(MouseEvent.RIGHT_MOUSE_UP, linePaintUp);
            else
                st.removeEventListener(MouseEvent.MOUSE_UP, linePaintUp);
            linePaintUp = null;
        }
        linePaintEndOnRight = false;
        if (!commit && linePaintSnapshot != null)
            boardData = BoardUtils.copyBoard(linePaintSnapshot);
        linePaintSnapshot = null;
        refreshBoardGraphics();
    }

    /**
     * Integer Bresenham line in column-major stepping; fills each grid cell along the segment.
     */
    function applyLineToBoard(c0:Int, r0:Int, c1:Int, r1:Int):Void {
        for (p in bresenhamCells(c0, r0, c1, r1)) {
            if (linePaintFill == "")
                boardData[p.r][p.c] = "";
            else
                boardData[p.r][p.c] = linePaintFill;
        }
    }

    function bresenhamCells(c0:Int, r0:Int, c1:Int, r1:Int):Array<{c:Int, r:Int}> {
        var out:Array<{c:Int, r:Int}> = [];
        var x0 = c0;
        var y0 = r0;
        var x1 = c1;
        var y1 = r1;
        var dx = Std.int(Math.abs(x1 - x0));
        var dy = -Std.int(Math.abs(y1 - y0));
        var sx = x0 < x1 ? 1 : -1;
        var sy = y0 < y1 ? 1 : -1;
        var err = dx + dy;
        var x = x0;
        var y = y0;
        while (true) {
            if (x >= 0 && y >= 0 && x < cols && y < rows)
                out.push({c: x, r: y});
            if (x == x1 && y == y1)
                break;
            var e2 = 2 * err;
            if (e2 >= dy) {
                err += dy;
                x += sx;
            }
            if (e2 <= dx) {
                err += dx;
                y += sy;
            }
        }
        return out;
    }

    function startToolboxDrag(pieceId:String, stageX:Float, stageY:Float):Void {
        cancelActiveDrag();
        dragFromBoard = null;
        dragBmp = pieceBitmap(pieceId, tileSize);
        addChild(dragBmp);
        positionDrag(stageX, stageY);
        var st = Lib.current.stage;
        function move(e:MouseEvent):Void {
            positionDrag(e.stageX, e.stageY);
        }
        function up(e:MouseEvent):Void {
            st.removeEventListener(MouseEvent.MOUSE_MOVE, move);
            st.removeEventListener(MouseEvent.MOUSE_UP, up);
            stageMoveHandler = null;
            stageUpHandler = null;
            var lp = boardViewport.world.globalToLocal(new Point(e.stageX, e.stageY));
            var c = Std.int(Math.floor(lp.x / tileSize));
            var r = Std.int(Math.floor(lp.y / tileSize));
            if (dragBmp != null && dragBmp.parent != null)
                removeChild(dragBmp);
            dragBmp = null;
            if (c >= 0 && r >= 0 && c < cols && r < rows)
                boardData[r][c] = pieceId;
            refreshBoardGraphics();
        }
        stageMoveHandler = move;
        stageUpHandler = up;
        st.addEventListener(MouseEvent.MOUSE_MOVE, move);
        st.addEventListener(MouseEvent.MOUSE_UP, up);
    }

    function startBoardDrag(r:Int, c:Int, pieceId:String, stageX:Float, stageY:Float):Void {
        cancelActiveDrag();
        dragFromBoard = {r: r, c: c, id: pieceId};
        boardData[r][c] = "";
        refreshBoardGraphics();
        dragBmp = pieceBitmap(pieceId, tileSize);
        addChild(dragBmp);
        positionDrag(stageX, stageY);
        var st = Lib.current.stage;
        function move(e:MouseEvent):Void {
            positionDrag(e.stageX, e.stageY);
        }
        function up(e:MouseEvent):Void {
            st.removeEventListener(MouseEvent.MOUSE_MOVE, move);
            st.removeEventListener(MouseEvent.MOUSE_UP, up);
            stageMoveHandler = null;
            stageUpHandler = null;
            var lp = boardViewport.world.globalToLocal(new Point(e.stageX, e.stageY));
            var pid = dragFromBoard != null ? dragFromBoard.id : null;
            dragFromBoard = null;
            if (dragBmp != null && dragBmp.parent != null)
                removeChild(dragBmp);
            dragBmp = null;
            if (pid == null) {
                refreshBoardGraphics();
                return;
            }
            var inside = lp.x >= 0 && lp.y >= 0 && lp.x < cols * tileSize && lp.y < rows * tileSize;
            if (inside) {
                var tc = Std.int(Math.floor(lp.x / tileSize));
                var tr = Std.int(Math.floor(lp.y / tileSize));
                if (tc >= 0 && tr >= 0 && tc < cols && tr < rows)
                    boardData[tr][tc] = pid;
            }
            refreshBoardGraphics();
        }
        stageMoveHandler = move;
        stageUpHandler = up;
        st.addEventListener(MouseEvent.MOUSE_MOVE, move);
        st.addEventListener(MouseEvent.MOUSE_UP, up);
    }

    function positionDrag(stageX:Float, stageY:Float):Void {
        if (dragBmp == null)
            return;
        var lp = globalToLocal(new Point(stageX, stageY));
        dragBmp.x = lp.x - tileSize * 0.45;
        dragBmp.y = lp.y - tileSize * 0.45;
    }

    function cancelActiveDrag():Void {
        endLinePaint(false);
        var st = Lib.current.stage;
        if (toolboxProbeMove != null)
            st.removeEventListener(MouseEvent.MOUSE_MOVE, toolboxProbeMove);
        if (toolboxProbeUp != null)
            st.removeEventListener(MouseEvent.MOUSE_UP, toolboxProbeUp);
        toolboxProbeMove = null;
        toolboxProbeUp = null;
        if (stageMoveHandler != null)
            st.removeEventListener(MouseEvent.MOUSE_MOVE, stageMoveHandler);
        if (stageUpHandler != null)
            st.removeEventListener(MouseEvent.MOUSE_UP, stageUpHandler);
        stageMoveHandler = null;
        stageUpHandler = null;
        if (dragBmp != null && dragBmp.parent != null)
            removeChild(dragBmp);
        dragBmp = null;
        if (dragFromBoard != null) {
            var d = dragFromBoard;
            if (boardData[d.r][d.c] == "")
                boardData[d.r][d.c] = d.id;
            dragFromBoard = null;
            refreshBoardGraphics();
        }
    }

    function refreshLoadDropdown(selectId:Null<String>):Void {
        var ch = BoardLayout.layoutChoices();
        var ids = [for (c in ch) c.id];
        var labels = [for (c in ch) c.label];
        var cur = selectId != null ? selectId : BoardLayout.DEFAULT_LAYOUT_ID;
        loadDropdown.setItems(ids, labels, cur);
    }

    public function refreshDropdownFromSettings():Void {
        refreshLoadDropdown(SettingsConfig.boardLayoutId);
    }

    function onLoadLayoutChoice(id:String):Void {
        if (id == null || id == "")
            return;
        var layout = BoardLayout.getLayoutById(id);
        if (layout == null || layout.length == 0)
            return;
        rows = layout.length;
        cols = layout[0] != null ? layout[0].length : 8;
        boardData = BoardUtils.copyBoard(layout);
        colsField.setText(Std.string(cols));
        rowsField.setText(Std.string(rows));
        if (StringTools.startsWith(id, "custom_")) {
            editingCustomId = id;
            var ent = CustomLayoutsStore.instance.getEntry(id);
            if (ent != null)
                nameField.setText(ent.name);
        } else {
            editingCustomId = null;
            nameField.setText(suggestNameForPreset(id));
        }
        refreshBoardGraphics();
    }

    function suggestNameForPreset(id:String):String {
        return switch (id) {
            case "classic": "From standard chess";
            case "chess960": "From Chess960";
            case "double_chess_16x12", "double_chess_16x8": "From Double Chess";
            default: "My layout";
        };
    }

    function onSaveClick():Void {
        var nm = StringTools.trim(nameField.getText());
        if (nm == "")
            nm = "Untitled layout";
        if (editingCustomId != null) {
            CustomLayoutsStore.instance.updateExisting(editingCustomId, nm, cols, rows, boardData);
            refreshLoadDropdown(editingCustomId);
        } else {
            var newId = CustomLayoutsStore.instance.addNew(nm, cols, rows, boardData);
            editingCustomId = newId;
            refreshLoadDropdown(newId);
        }
        if (onLayoutsChanged != null)
            onLayoutsChanged();
    }

    /** Always creates a new saved layout entry (does not overwrite the current custom id). */
    function onSaveAsNewClick():Void {
        var nm = StringTools.trim(nameField.getText());
        if (nm == "")
            nm = "Untitled layout";
        var newId = CustomLayoutsStore.instance.addNew(nm, cols, rows, boardData);
        editingCustomId = newId;
        refreshLoadDropdown(newId);
        if (onLayoutsChanged != null)
            onLayoutsChanged();
    }

    /**
     * Resize the tab for a new content size without resetting board data, tool selection, or editor fields.
     */
    public function setContentSize(contentWidth:Int, viewportHeight:Int):Void {
        cancelActiveDrag();
        viewportH = viewportHeight;
        innerW = contentWidth - 20;
        rightPanelWidth = Std.int(Math.min(520, Math.max(240, Math.floor(innerW * 0.34))));
        boardAreaW = Std.int(Math.max(160, innerW - rightPanelWidth - 28));

        if (headerTitleTf != null)
            headerTitleTf.width = innerW;
        if (headerBlurbTf != null)
            headerBlurbTf.width = innerW;

        boardViewport.x = boardLeft;
        boardViewport.y = boardTop;
        var clipH = viewportH - Std.int(boardTop) - 8;
        if (clipH < 80)
            clipH = 80;
        boardViewport.setClipSize(boardAreaW, clipH);

        rightPanel.x = boardLeft + boardAreaW + 12;
        var panelH = viewportH - Std.int(MAIN_SPLIT_Y) - 10;
        if (panelH < 200)
            panelH = 200;
        panelBg.graphics.clear();
        panelBg.graphics.beginFill(0x242428);
        panelBg.graphics.lineStyle(1, 0x454545);
        panelBg.graphics.drawRoundRect(0, 0, rightPanelWidth, panelH, 10, 10);
        panelBg.graphics.endFill();

        var ddW = rightPanelWidth - 24;
        loadDropdown.setDropdownWidth(ddW);
        nameField.setFieldSize(ddW, 26);
        var btnHalf = Std.int((ddW - 8) / 2);
        var btnSecond = ddW - 8 - btnHalf;
        saveLayoutBtn.setButtonSize(btnHalf, 28);
        saveAsNewBtn.setButtonSize(btnSecond, 28);
        saveAsNewBtn.x = 12 + btnHalf + 8;
        deleteSavedBtn.setButtonSize(ddW, 28);

        while (rightPanel.numChildren > firstToolboxChildIndex)
            rightPanel.removeChildAt(rightPanel.numChildren - 1);

        var py = toolboxBlockStartPy;
        addLabelTo(rightPanel, "Toolbox", new TextFormat("Arial", 12, 0xFFFFFF, true), 12, py, 200, 20);
        py += 24;
        addLabelTo(
            rightPanel,
            "Click piece to select. Drag from toolbox to place one. On board: click or hold-drag for a line.",
            new TextFormat("Arial", 9, 0x999999),
            12,
            py,
            rightPanelWidth - 16,
            40
        );
        py += 44;
        var toolboxViewportH = panelH - py - 14;
        if (toolboxViewportH < 96)
            toolboxViewportH = 96;
        buildToolboxInPanel(rightPanel, 12, py, toolboxViewportH);

        refreshBoardGraphics();
    }

    function onDeleteClick():Void {
        if (editingCustomId == null)
            return;
        var removedId = editingCustomId;
        CustomLayoutsStore.instance.remove(removedId);
        editingCustomId = null;
        nameField.setText("My layout");
        if (SettingsConfig.boardLayoutId == removedId) {
            SettingsConfig.boardLayoutId = BoardLayout.DEFAULT_LAYOUT_ID;
            SettingsConfig.save();
        }
        refreshLoadDropdown(BoardLayout.DEFAULT_LAYOUT_ID);
        onLoadLayoutChoice(BoardLayout.DEFAULT_LAYOUT_ID);
        if (onLayoutsChanged != null)
            onLayoutsChanged();
    }

    function addLabel(text:String, fmt:TextFormat, size:Int, x:Float, y:Float, w:Float, h:Float):TextField {
        var tf = new TextField();
        tf.defaultTextFormat = fmt;
        tf.text = text;
        tf.x = x;
        tf.y = y;
        tf.width = w;
        tf.height = h;
        tf.selectable = false;
        tf.mouseEnabled = false;
        addChild(tf);
        return tf;
    }
}
