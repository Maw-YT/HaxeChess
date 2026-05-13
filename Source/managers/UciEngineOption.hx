package managers;

/**
 * One UCI "option" line from the engine (spin, check, combo, string, button).
 */
typedef UciEngineOption = {
    var name:String;
    var type:String;
    var defaultValue:String;
    var min:String;
    var max:String;
    var comboValues:Array<String>;
}
