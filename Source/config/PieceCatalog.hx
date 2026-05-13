package config;

import utils.BoardToFEN;

/**
 * Runtime registry built from `PieceCatalogEntries` + `PieceCatalogMetrics`.
 * `PieceFactory.init` calls `rebuild(true)` then registers each `PieceDef.factory`.
 */
class PieceCatalog {
    static var installed:Bool = false;
    static var entries:Array<PieceDef> = [];
    static var byId:Map<String, PieceDef> = new Map();

    public static function rebuild(force:Bool = false):Void {
        if (installed && !force)
            return;
        entries = PieceCatalogEntries.build();
        byId = new Map();
        for (e in entries)
            byId.set(e.id, e);

        var values:Map<String, Int> = new Map();
        var typeToFen:Map<String, String> = new Map();
        var fenToType:Map<String, String> = new Map();
        var typeToEngineFen:Map<String, String> = new Map();

        for (e in entries) {
            values.set(e.id, e.value);
            typeToFen.set(e.id, e.fenLower);
            typeToEngineFen.set(e.id, e.engineFenLower != null ? e.engineFenLower : e.fenLower);
            if (e.includeInFenDecode && e.fenLower != "")
                fenToType.set(e.fenLower, e.id);
        }

        GameConfig.PIECE_VALUES = values;
        BoardToFEN.refreshPieceFenTables(typeToFen, fenToType, typeToEngineFen);
        installed = true;
    }

    public static function definitions():Array<PieceDef> {
        ensureInstalled();
        return entries;
    }

    public static function toolboxPieceIds(color:String):Array<String> {
        ensureInstalled();
        var out:Array<String> = [];
        for (e in entries) {
            if (!e.toolbox)
                continue;
            out.push(e.id + "-" + color);
        }
        return out;
    }

    public static function allTypeIds():Array<String> {
        ensureInstalled();
        return [for (e in entries) e.id];
    }

    public static function get(id:String):Null<PieceDef> {
        ensureInstalled();
        return byId.get(id);
    }

    public static function openingPhaseWeight(type:String):Int {
        var e = get(type);
        return e != null ? e.openingPhase : 4;
    }

    public static function pstKind(type:String):Int {
        var e = get(type);
        return e != null ? e.pst : PieceCatalogMetrics.PST_FALLBACK;
    }

    public static function drawClass(type:String):Int {
        var e = get(type);
        if (e == null)
            return PieceCatalogMetrics.DRAW_DEFAULT_HEAVY;
        return e.draw;
    }

    public static function renderAsType(type:String):Null<String> {
        var e = get(type);
        return e != null ? e.renderAs : null;
    }

    public static function fallbackKingCentral(type:String):Bool {
        var e = get(type);
        return e != null && e.fallbackKingCentral;
    }

    static function ensureInstalled():Void {
        if (!installed)
            rebuild(false);
    }
}
