package renderers;

import openfl.display.Sprite;
import openfl.display.Bitmap;
import openfl.utils.Assets;
import motion.Actuate;
import motion.easing.Linear;
import motion.easing.Quad;
import interfaces.IPieceRenderer;
import config.GameConfig;
import config.PieceCatalog;
import utils.BoardUtils;

/**
 * Handles rendering and animating pieces
 */
class PieceRenderer extends Sprite implements IPieceRenderer {
    private var tileSize:Int;
    private var pieceMap:Map<String, Bitmap>;
    private var hiddenPieces:Map<String, Bool>;

    public function new(tileSize:Int) {
        super();
        this.tileSize = tileSize;
        this.pieceMap = new Map();
        this.hiddenPieces = new Map();
    }

    public function setTileSize(size:Int):Void {
        if (size < 8)
            return;
        tileSize = size;
    }

    public function replaySquareWithSpawn(row:Int, col:Int, pieceId:String):Void {
        if (pieceId == "")
            return;
        var k = getKey(row, col);
        hiddenPieces.remove(k);
        if (pieceMap.exists(k)) {
            disposeBitmap(pieceMap.get(k));
            pieceMap.remove(k);
        }
        createPieceAt(row, col, pieceId, true);
    }

    public function render(boardData:Array<Array<String>>, animateSpawns:Bool = false):Void {
        clear();

        for (row in 0...GameConfig.boardRows) {
            for (col in 0...GameConfig.boardCols) {
                createPieceAt(row, col, boardData[row][col], animateSpawns);
            }
        }
    }

    public function clear():Void {
        while (numChildren > 0) {
            var d = getChildAt(0);
            Actuate.stop(d, null, false, false);
            removeChildAt(0);
        }
        pieceMap = new Map();
        hiddenPieces = new Map();
    }

    /**
     * @param animated If true (click move), the mover tweens to the destination; if false (drag), it snaps there.
     *        Any capture / en-passant victim always plays `animatePieceDeath` in parallel with the mover (never sequential).
     */
    public function animateMove(startR:Int, startC:Int, endR:Int, endC:Int, pieceId:String, callback:Void->Void, ?enPassantVictimRow:Null<Int>,
            ?enPassantVictimCol:Null<Int>, ?animated:Bool = true):Void {
        var key = getKey(startR, startC);
        var bmp = pieceMap.get(key);

        if (bmp == null) {
            callback();
            return;
        }

        hiddenPieces.remove(key);
        bmp.visible = true;

        var targetKey = getKey(endR, endC);

        var epVictim:Bitmap = null;
        if (enPassantVictimRow != null && enPassantVictimCol != null) {
            var vk = getKey(enPassantVictimRow, enPassantVictimCol);
            if (pieceMap.exists(vk)) {
                epVictim = pieceMap.get(vk);
                pieceMap.remove(vk);
            }
        }

        var capturedPiece:Bitmap = null;
        if (pieceMap.exists(targetKey)) {
            capturedPiece = pieceMap.get(targetKey);
            pieceMap.remove(targetKey);
        }

        pieceMap.remove(key);
        pieceMap.set(targetKey, bmp);
        addChild(bmp);

        var tx = endC * tileSize;
        var ty = endR * tileSize;

        var pending = 0;
        var finished = false;
        function markDone():Void {
            pending--;
            if (pending <= 0 && !finished) {
                finished = true;
                callback();
            }
        }

        if (epVictim != null) {
            pending++;
            animatePieceDeath(epVictim, markDone);
        }
        if (capturedPiece != null) {
            pending++;
            animatePieceDeath(capturedPiece, markDone);
        }

        pending++;
        if (animated) {
            Actuate.tween(bmp, GameConfig.ANIMATION_DURATION, { x: tx, y: ty })
                .ease(Linear.easeNone)
                .onComplete(markDone);
        } else {
            Actuate.stop(bmp, null, false, false);
            bmp.x = tx;
            bmp.y = ty;
            markDone();
        }
    }

    public function animateCastling(kingStartR:Int, kingStartC:Int, kingEndR:Int, kingEndC:Int,
            rookStartR:Int, rookStartC:Int, rookEndR:Int, rookEndC:Int, callback:Void->Void, ?animated:Bool = true):Void {
        var kingKey = getKey(kingStartR, kingStartC);
        var rookKey = getKey(rookStartR, rookStartC);

        var kingBmp = pieceMap.get(kingKey);
        var rookBmp = pieceMap.get(rookKey);

        if (kingBmp != null && rookBmp != null) {
            hiddenPieces.remove(kingKey);
            kingBmp.visible = true;
            hiddenPieces.remove(rookKey);
            rookBmp.visible = true;

            var kingTargetKey = getKey(kingEndR, kingEndC);
            var rookTargetKey = getKey(rookEndR, rookEndC);

            pieceMap.remove(kingKey);
            pieceMap.set(kingTargetKey, kingBmp);

            pieceMap.remove(rookKey);
            pieceMap.set(rookTargetKey, rookBmp);

            var kx = kingEndC * tileSize;
            var ky = kingEndR * tileSize;
            var rx = rookEndC * tileSize;
            var ry = rookEndR * tileSize;

            addChild(kingBmp);
            addChild(rookBmp);

            if (animated) {
                Actuate.tween(kingBmp, GameConfig.ANIMATION_DURATION, { x: kx, y: ky })
                    .ease(Linear.easeNone);
                Actuate.tween(rookBmp, GameConfig.ANIMATION_DURATION, { x: rx, y: ry })
                    .ease(Linear.easeNone)
                    .onComplete(callback);
            } else {
                Actuate.stop(kingBmp, null, false, false);
                Actuate.stop(rookBmp, null, false, false);
                kingBmp.x = kx;
                kingBmp.y = ky;
                rookBmp.x = rx;
                rookBmp.y = ry;
                callback();
            }
        } else {
            callback();
        }
    }

    public function updateTile(row:Int, col:Int, newId:String):Void {
        var key = getKey(row, col);
        if (pieceMap.exists(key)) {
            var oldBmp = pieceMap.get(key);
            pieceMap.remove(key);
            if (newId == "") {
                animatePieceDeath(oldBmp, function() {});
            } else {
                animatePieceDeath(oldBmp, function() createPieceAt(row, col, newId, true));
            }
        } else if (newId != "") {
            createPieceAt(row, col, newId, true);
        }
    }

    public function createDragPiece(pieceId:String):openfl.display.Bitmap {
        if (pieceId == "")
            return null;

        var assetPath = getAssetPath(pieceId);
        var bmp = new Bitmap(Assets.getBitmapData(assetPath));
        bmp.smoothing = true;
        applyTileStretch(bmp);
        return bmp;
    }

    public function hidePieceAt(row:Int, col:Int):Void {
        var key = getKey(row, col);
        hiddenPieces.set(key, true);

        var bmp = pieceMap.get(key);
        if (bmp != null) {
            bmp.visible = false;
        }
    }

    public function showPieceAt(row:Int, col:Int):Void {
        var key = getKey(row, col);
        hiddenPieces.remove(key);

        var bmp = pieceMap.get(key);
        if (bmp != null) {
            bmp.visible = true;
        }
    }

    private function createPieceAt(row:Int, col:Int, id:String, doSpawn:Bool):Void {
        if (id == "")
            return;

        var assetPath = getAssetPath(id);
        var bmp = new Bitmap(Assets.getBitmapData(assetPath));

        bmp.smoothing = true;
        var tx = col * tileSize;
        var ty = row * tileSize;
        bmp.x = tx;
        bmp.y = ty;
        bmp.alpha = 1;
        bmp.rotation = 0;
        applyTileStretch(bmp);

        addChild(bmp);
        var key = getKey(row, col);
        pieceMap.set(key, bmp);

        if (hiddenPieces.exists(key)) {
            bmp.visible = false;
        } else if (doSpawn) {
            applySpawnAnim(bmp);
        }
    }

    /** Match legacy `width/height = tileSize`: stretch (or shrink) texture to the square cell. */
    private function applyTileStretch(bmp:Bitmap):Void {
        var bd = bmp.bitmapData;
        if (bd == null || bd.width <= 0 || bd.height <= 0)
            return;
        bmp.scaleX = tileSize / bd.width;
        bmp.scaleY = tileSize / bd.height;
    }

    /**
     * Pop-in using the *tile* scale targets. Never tween scale to 1 — that resets to native texture
     * pixels and makes pieces huge until the next full render without spawn.
     */
    private function applySpawnAnim(bmp:Bitmap):Void {
        var sx = bmp.scaleX;
        var sy = bmp.scaleY;
        bmp.alpha = 0;
        bmp.scaleX = sx * 0.66;
        bmp.scaleY = sy * 0.66;
        Actuate.tween(bmp, GameConfig.PIECE_SPAWN_DURATION, { alpha: 1, scaleX: sx, scaleY: sy })
            .ease(Quad.easeOut);
    }

    /** Stop tweens and detach a piece bitmap (no animation). */
    private function disposeBitmap(bmp:Bitmap):Void {
        Actuate.stop(bmp, null, false, false);
        if (bmp.parent == this)
            removeChild(bmp);
    }

    private function animatePieceDeath(bmp:Bitmap, onDone:Void->Void):Void {
        Actuate.stop(bmp, null, false, false);
        var bd = bmp.bitmapData;
        if (bd == null || bd.width <= 0 || bd.height <= 0) {
            disposeBitmap(bmp);
            onDone();
            return;
        }

        var sx0 = bmp.scaleX;
        var sy0 = bmp.scaleY;
        var w0 = bd.width * sx0;
        var h0 = bd.height * sy0;
        var cx = bmp.x + w0 * 0.5;
        var cy = bmp.y + h0 * 0.5;

        var endK = 0.22;
        var sx1 = sx0 * endK;
        var sy1 = sy0 * endK;
        var w1 = bd.width * sx1;
        var h1 = bd.height * sy1;

        var drift = (Math.random() > 0.5 ? 1.0 : -1.0) * tileSize * 0.035;
        var endX = cx - w1 * 0.5 + drift;
        var endY = cy - h1 * 0.5 + tileSize * 0.05;
        var rot = bmp.rotation + (Math.random() > 0.5 ? 9 : -9);

        Actuate.tween(bmp, GameConfig.PIECE_DEATH_DURATION, {
            alpha: 0,
            scaleX: sx1,
            scaleY: sy1,
            x: endX,
            y: endY,
            rotation: rot
        })
            .ease(Quad.easeIn)
            .onComplete(function() {
                disposeBitmap(bmp);
                onDone();
            });
    }

    private function getAssetPath(id:String):String {
        var assetPath = GameConfig.ASSETS_PATH + id + ".png";
        if (!Assets.exists(assetPath)) {
            var parsed = BoardUtils.parsePieceId(id);
            var ra = PieceCatalog.renderAsType(parsed.type);
            if (ra != null && ra != "") {
                var altPath = GameConfig.ASSETS_PATH + ra + "-" + parsed.color + ".png";
                if (Assets.exists(altPath))
                    return altPath;
            }
            assetPath = GameConfig.ASSETS_PATH + GameConfig.MISSING_ASSET;
        }
        return assetPath;
    }

    private function getKey(row:Int, col:Int):String {
        return row + "-" + col;
    }
}
