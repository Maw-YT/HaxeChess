package config;

import interfaces.IPiece;

typedef PieceDef = {
    var id:String;
    var fenLower:String;
    var value:Int;
    var factory:String->IPiece;
    var engineFenLower:Null<String>;
    var includeInFenDecode:Bool;
    var toolbox:Bool;
    var openingPhase:Int;
    var pst:Int;
    var draw:Int;
    var fallbackKingCentral:Bool;
    var renderAs:Null<String>;
};
