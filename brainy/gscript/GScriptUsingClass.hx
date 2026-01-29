package brainy.gscript;

/**
 * This is used to mark classes that can be used with the `using` keyword.
 * You can also add @:gscriptUsableEntry to your class.
 * If you wanna force the class to be called with any type, you can add @:gscriptUsableEntry(forceAny)
**/
@:autoBuild(brainy.gscript.macro.UsingMacro.build())
interface GScriptUsingClass {}
