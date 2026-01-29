package brainy.gscript;

import brainy.gscript.utils.Ansi;
import brainy.hscript.proxy.ProxyType;
import haxe.ds.StringMap;
import brainy.hscript.*;
import brainy.gscript.ErrorSeverity;
import brainy.gscript.GScriptConfig;
import brainy.gscript.utils.UsingEntry;

using brainy.gscript.utils.Ansi;

@:structInit
class GScriptCall {
	/**
	 * an HScript Function Name.
	**/
	public var funName: String;

	/**
	 * an HScript Function's signature.
	**/
	public var signature: Dynamic;

	/**
	 * an HScript Method's return value.
	**/
	public var returnValue: Dynamic;
}

/**
 * This basic object helps with the creation of scripts,
 * along with having neat helper functions to initialize and stop scripts
 *
 * It is highly recommended that you override this class to add custom defualt variables and such.
**/
class GScript {
	/**
	 * Map with stored instances of scripts.
	**/
	public static var instances: StringMap<GScript> = new StringMap<GScript>();

	public static var registeredUsingEntries: Array<UsingEntry> = [
		new UsingEntry("StringTools", function(o: Dynamic, f: String, args: Array<Dynamic>): Dynamic {
			if (f == "isEof") // has @:noUsing
				return null;
			switch (Type.typeof(o)) {
				case TInt if (f == "hex"):
					return StringTools.hex(o, args[0]);
				case TClass(String):
					if (Reflect.hasField(StringTools, f)) {
						var field = Reflect.field(StringTools, f);
						if (Reflect.isFunction(field)) {
							return Reflect.callMethod(StringTools, field, [o].concat(args));
						}
					}
				default:
			}
			return null;
		}),
		new UsingEntry("Lambda", function(o: Dynamic, f: String, args: Array<Dynamic>): Dynamic {
			if (Tools.isIterable(o)) {
				// TODO: Check if the values are Iterable<T>
				if (Reflect.hasField(Lambda, f)) {
					var field = Reflect.field(Lambda, f);
					if (Reflect.isFunction(field)) {
						return Reflect.callMethod(Lambda, field, [o].concat(args));
					}
				}
			}
			return null;
		}),
	];

	/**
	 * Contains Classes/Enums that cannot be accessed via HScript.
	 *
	 * you may find this useful if you want your project to be more secure.
	**/
	@:unreflective public static var blocklistImports: Array<String> = [];

	/**
	 * Contains proxies for classes. So they can be sandboxed or add extra functionality.
	**/
	@:unreflective public static var proxyImports: Map<String, Dynamic> = ["Type" => ProxyType];

	public static function addBlocklistImport(name: String): Void {
		blocklistImports.push(name);
	}

	public static function addProxyImport(name: String, value: Dynamic): Void {
		proxyImports.set(name, value);
	}

	public static function getProxiedImport(name: String): Dynamic {
		return proxyImports.get(name);
	}

	private static function getDefaultPos(name: String = "GScript"): haxe.PosInfos {
		return {
			fileName: name,
			lineNumber: -1,
			className: "UnknownClass",
			methodName: "unknownFunction",
			customParams: null
		}
	}

	/**
	 * Custom warning function for script wrappers.
	 *
	 * Overriding is recommended if you're doing custom error handling.
	**/
	public dynamic static function logLevel(level: ErrorSeverity, x, ?pos: haxe.PosInfos): Void {
		if (pos == null) {
			pos = getDefaultPos();
		}

		var out = Std.string(x);
		if (pos != null && pos.customParams != null)
			for (i in pos.customParams)
				out += "," + i;

		var prefix = ErrorSeverityTools.getPrefix(level);
		if (prefix != "" && prefix != null) {
			prefix = '$prefix:';
		}
		var posPrefix = '[$prefix${pos.fileName}]';
		if (pos.lineNumber != -1)
			posPrefix = '[$prefix${pos.fileName}:${pos.lineNumber}]';

		if (prefix != "" && prefix != null) {
			posPrefix = posPrefix.fg(ErrorSeverityTools.getColor(level)).reset();
			if (level == FATAL) {
				posPrefix = posPrefix.attr(INTENSITY_BOLD);
			}
		}
		#if sys
		Sys.println((posPrefix + ": " + out).stripColor());
		#else
		// Since non-sys targets lack printLn, a simple trace should work
		trace((posPrefix + ": " + out).stripColor());
		#end
	}

	/**
	 * Custom print function for script wrappers.
	**/
	public dynamic static function print(x, ?pos: haxe.PosInfos): Void {
		logLevel(NONE, x, pos);
	}

	/**
	 * Custom error function for script wrappers.
	**/
	public dynamic static function error(x, ?pos: haxe.PosInfos): Void {
		logLevel(ERROR, x, pos);
	}

	/**
	 * Custom warning function for script wrappers.
	 *
	 * Overriding is recommended if you're doing custom error handling.
	**/
	public dynamic static function warn(x, ?pos: haxe.PosInfos): Void {
		logLevel(WARN, x, pos);
	}

	/**
	 * Custom fatal error function for script wrappers.
	**/
	public dynamic static function fatal(x, ?pos: haxe.PosInfos): Void {
		logLevel(FATAL, x, pos);
	}

	/**
	 * Config file, set when creating a new `GScript` instance.
	**/
	public var config: GScriptConfig = null;

	/**
	 * Current script name, from `config.name`.
	**/
	public var name(get, never): String;

	inline function get_name(): String
		return config.name;

	/**
	 * The code passed in the `new` function for this script.
	 *
	 * contains a full haxe script instance
	**/
	var scriptCode: String = "";

	/**
	 * Current initialized script interpreter.
	**/
	var interp: Interp;

	/**
	 * Current initialized script parser.
	**/
	var parser: Parser;

	/**
	 * Current initialized script expression.
	**/
	var expr: Expr;

	/**
	 * Helper variable for the error string caused by a nulled interpreter.
	**/
	final interpErrStr: String = "Careful, the interpreter hasn't been initialized";

	/**
	 * Instantiates a new Script with the string value.
	 *
	 * ```haxe
	 * trace("Hello World!");
	 * ```
	 *
	 * will trace "Hello World!" to the standard output.
	 * @param scriptCode      the script to be parsed, e.g:
	 */
	public function new(scriptCode: String, ?config: AutoGScriptConfig): Void {
		if (config == null)
			config = new GScriptConfig("GScript", true, true, []);
		this.scriptCode = scriptCode;
		this.config = GScriptConfig.from(config);
		this.config.name = fixScriptName(this.name);

		parser = new Parser();
		interp = new Interp();
		interp.showPosOnLog = false;

		parser.allowTypes = true;
		parser.allowMetadata = true;
		parser.allowJSON = true;

		// set variables to the interpreter.
		if (this.config.autoPreset)
			preset();
		// run the script.
		if (this.config.autoRun)
			execute();
	}

	private static function fixScriptName(toFix: String): String {
		// makes sure that we never have instances with identical names.
		var _name = toFix;
		var copyID: Int = 1;
		while (GScript.instances.exists(_name)) {
			_name = toFix + "_" + copyID;
			copyID += 1;
		}
		return _name;
	}

	/**
	 * Executes this script and returns the interp's run result.
	**/
	public function execute(): Dynamic {
		// I'm sorry but if you just decide to destroy the script at will, that's your fault
		if (interp == null)
			throw "Attempt to run script failed, script is probably destroyed.";

		if (expr == null)
			expr = parse();

		GScript.instances.set(this.name, this);
		this.config.packageName = parser.packageName;
		return interp.execute(expr);
	}

	/**
	 * If you want to override the script, you should do parse(true);
	 *
	 * just parse(); otherwise, forcing may fix some behaviour depending on your implementation.
	**/
	public function parse(force: Bool = false) {
		if (force || expr == null) {
			expr = parser.parseString(scriptCode, this.name);
		}
		return expr;
	}

	/**
	 * Appends Default Classes/Enums for the Script to use.
	**/
	public function preset(): Void {
		set("Std", Std); // TODO: add a proxy for std
		set("StringTools", StringTools);
		set("Math", Math);
		#if hscriptPos
		// overriding trace for good measure.
		// if you're a game developer or a fnf modder (hi guys),
		// you might wanna use GScript.print for your on-screen consoles and such.
		set("trace", Reflect.makeVarArgs(function(x: Array<Dynamic>) {
			var pos = this.interp != null ? this.interp.posInfos() : GScript.getDefaultPos(this.name);
			var v = x.shift();
			if (x.length > 0)
				pos.customParams = x;
			GScript.print(v, pos);
		}));
		#end
	}

	/**
	 * Returns a field from the script.
	 * @param field 	The field that needs to be looked for.
	 */
	public function get(field: String): Dynamic {
		#if gscript_DEBUG
		if (interp == null)
			GScript.fatal("[GScript:get()]: " + interpErrStr + ", when trying to get variable \"" + field + "\", returning false...");
		#end
		return interp != null ? interp.variables.get(field) : false;
	}

	/**
	 * Sets a new field to the script
	 * @param name          The name of your new field, scripts will be able to use the field with the name given.
	 * @param value         The value for your new field.
	 * @param allowOverride If set to true, when setting the new field, we will ignore any previously set fields of the same name.
	 */
	public function set(name: String, value: Dynamic, allowOverride: Bool = true): Void {
		if (interp == null || interp.variables == null) {
			#if gscript_DEBUG
			GScript.fatal("[GScript:set()]: " + interpErrStr + ", when trying to set variable \"" + name + "\" so variables cannot be set.");
			#end
			return;
		}

		if (allowOverride || !interp.variables.exists(name))
			interp.variables.set(name, value);
	}

	/**
	 * Calls a method on the script
	 * @param fun       The name of the method you wanna call.
	 * @param args      The arguments that the method needs.
	 */
	public function call(fun: String, ?args: Array<Dynamic>): GScriptCall {
		if (interp == null) {
			#if gscript_DEBUG
			trace("[GScript:call()]: " + interpErrStr + ", so functions cannot be called.");
			#end
			return null;
		}

		if (args == null)
			args = [];

		// fun-ny
		var ny: Dynamic = interp.variables.get(fun); // function signature
		var isFunction: Bool = false;
		try {
			isFunction = ny != null && Reflect.isFunction(ny);
			if (!isFunction)
				throw 'Tried to call a non-function, for "$fun"';
			// throw "Variable not found or not callable, for \"" + fun + "\"";

			final ret = Reflect.callMethod(null, ny, args);
			return {funName: fun, signature: ny, returnValue: ret};
		}
		// @formatter:off
		#if hscriptPos
		catch (e:Expr.Error) {
			GScript.error(Printer.errorToString(e, false), this.interp.posInfos());
		}
		#end
		catch (e:haxe.Exception) {
			var pos = isFunction ? this.interp.posInfos() : GScript.getDefaultPos(this.name);
			GScript.error(Std.string(e), pos);
		}
		// @formatter:on
		return null;
	}

	/**
	 * Checks the existance of a field or method within your script.
	 * @param field 		The field to check if exists.
	 */
	public function exists(field: String): Bool {
		#if gscript_DEBUG
		if (interp == null)
			trace("[GScript:exists()]: " + interpErrStr + ", returning false...");
		#end
		return (interp != null) ? interp.variables.exists(field) : false;
	}

	/**
	 * Destroys the current instance of this script
	 * along with its parser, and also removes it from the `GScript.instances` map.
	 *
	 * **WARNING**: this action CANNOT be undone.
	**/
	public function destroy(): Void {
		if (GScript.instances.exists(this.name))
			GScript.instances.remove(this.name);
		interp = null;
		parser = null;
	}

	/**
	 * Destroys every single script found within the `GScript.instances` map.
	 *
	 * **WARNING**: this action CANNOT be undone.
	**/
	public static function destroyAll(): Void {
		for (key in GScript.instances.keys()) {
			var gscript = GScript.instances.get(key);
			if (gscript.interp == null)
				continue;
			gscript.destroy();
		}

		GScript.instances.clear();
		GScript.instances = new StringMap<GScript>();
	}

	public static function registerUsingGlobal(name: String, call: UsingCall): UsingEntry {
		var entry = new UsingEntry(name, call);
		GScript.registeredUsingEntries.push(entry);
		return entry;
	}
}
