# HScript GScript

---

a [HScript](https://github.com/HaxeFoundation/hscript) extension made to make the process of creating a script way easier.

---

- [Setup](docs/SETUP.md)
- [Features](docs/FEATURES.md)
- [Usage](#usage)

---

# USAGE

Initializing a GScript Script should be fairly easy and very much self-explanatory

```haxe
// *
// assets/scripts/hi.hx
// *

// import somepackage.SomeModule;

final greeting:String = "Hello from GScript!";

function sayHello() {
	trace(greeting);

	/*
	// if you try this, this function will crash as `greeting` is a constant value
	greeting = "Uh Oh!";
	// if SomeModule was imported, you can use it here!
	var module:SomeModule = new SomeModule();
	*/
}

function countUpTo(number:Int) {
	for (i in 1...number+1)
		trace(i);
}

// *
// * src/Main.hx
// *

import brainy.gscript.GScript;
import brainy.gscript.GScriptConfig;

class Main {
	static function main():Void {
		// reminder that the rules are completely optional.
		final rules:RawGScriptConfig = {name: "My Script", autoRun: false, autoPreset: true};
		final getText:String->String = #if sys sys.io.File.getContent #elseif openfl openfl.utils.Assets.getText #end;
		var myScript:GScript = new GScript(getText("assets/scripts/hi.hx"), rules);

		// this is necessary in case the `autoRun` rule is disabled when initializing the script, if not it will initialize by itself.
		myScript.execute();

		myScript.call("sayHello"); // prints "Hello from GScript!"
		myScript.call("countUpTo", [5]); // prints "1, 2, 3, 4, 5"
	}
}

```
