var helloWorld: String = "Hello World";

function main() {
	trace(helloWorld);
}

var obj = {
	name: "Crow",
	age: -1
};

obj ??= {name: "Crow"};
trace(obj.name);
enum Test {
	A;
	B;
	C;
	D(a: Int);
}

final test = "GScript";
trace("Top level " + test);
