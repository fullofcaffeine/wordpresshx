package reflaxe.php.compiler;

enum abstract PhpSemanticCapabilityId(String) to String {
	var ApplicationSourceRoot = "module.application-source-root";
	var StaticClass = "module.static-class";
	var StaticVoidNoArgMethod = "declaration.static-void-no-arg-method";
	var StringLiteral = "value.string-literal";
	var InitializedStringLocal = "value.initialized-string-local";
	var SysPrintlnString = "call.sys-println-string";
	var UnsupportedAstDiagnostic = "diagnostic.unsupported-ast";
	var ExactHaxeRangeMap = "source-map.exact-haxe-ranges";
	var IntLiteral = "numeric.int-literal";
	var IntAddition = "numeric.int-addition";
	var InitializedIntLocal = "value.initialized-int-local";
	var IntEquality = "control.int-equality";
	var IfElse = "control.if-else";
	var IntAssignment = "control.int-assignment";
	var IntLessOrEqual = "control.int-less-or-equal";
	var WhileLoop = "control.while";
	var InstanceLayout = "module.instance-layout";
	var IntArrayLiteral = "collection.int-array-literal";
	var ProvenIntArrayRead = "collection.proven-int-array-read";
	var ArrayCollection = "collection.array";
	var RequiredIntParameters = "call.required-int-parameters";
	var IntReturn = "call.int-return";
	var StaticApplicationCall = "call.static-application-int-call";
	var Closure = "call.closure";
	var TryThrowCatch = "exception.try-throw-catch";
	var NullableValue = "null.nullable-value";
	var HaxeStdlib = "runtime.haxe-stdlib";
	var NumericEdgeSemantics = "numeric.overflow-division-modulo";
	var StringConcatenation = "string.concat-exact-operands";
	var StringEquality = "string.equality";
	var Utf8StringLiteralRoundTrip = "string.utf8-literal-round-trip";
	var UnicodeRuntime = "string.unicode-runtime";
	var CollectionOrdering = "ordering.collection-and-object";
	var PathEnvironment = "environment.path";
	var FileSystem = "environment.filesystem";
	var Network = "environment.network";
	var Timezone = "environment.timezone";

	public inline function value():String {
		return this;
	}
}

enum abstract PhpSemanticCategory(String) to String {
	var ModuleTypeLayout = "module-type-layout";
	var ValuesCollections = "values-collections";
	var ControlFlow = "control-flow";
	var CallsClosures = "calls-closures";
	var Exceptions = "exceptions";
	var NullBehavior = "null-behavior";
	var RuntimeStdlib = "runtime-stdlib";
	var Diagnostics = "diagnostics";
	var SourceMaps = "source-maps";
	var Numeric = "numeric";
	var StringUnicode = "string-unicode";
	var Ordering = "ordering";
	var PathEnvironmentFileSystemNetworkTimezone = "path-environment-filesystem-network-timezone";

	public inline function value():String {
		return this;
	}
}

enum abstract PhpSemanticCapabilityState(String) to String {
	var Admitted = "admitted";
	var UnsupportedOwned = "unsupported-owned";
	var UnverifiedOwned = "unverified-owned";

	public inline function value():String {
		return this;
	}
}

typedef PhpSemanticCapabilityRecord = {
	final id:PhpSemanticCapabilityId;
	final category:PhpSemanticCategory;
	final state:PhpSemanticCapabilityState;
	final evidence:String;
	final owner:String;
}

/** Single typed authority for admitted, unsupported, and unverified compiler semantics. **/
class PhpSemanticCapabilities {
	public static function records():Array<PhpSemanticCapabilityRecord> {
		final tracer = "bash compiler/reflaxe.php/scripts/test-compiler-tracer.sh";
		final semantic = "bash compiler/reflaxe.php/scripts/test-semantic-matrix.sh";
		final owner = "reflaxe.php-runtime-semantics";
		return [
			record(ApplicationSourceRoot, ModuleTypeLayout, Admitted, tracer, owner),
			record(StaticClass, ModuleTypeLayout, Admitted, tracer, owner),
			record(StaticVoidNoArgMethod, ModuleTypeLayout, Admitted, tracer, owner),
			record(StringLiteral, ValuesCollections, Admitted, semantic, owner),
			record(InitializedStringLocal, ValuesCollections, Admitted, semantic, owner),
			record(SysPrintlnString, CallsClosures, Admitted, semantic, owner),
			record(UnsupportedAstDiagnostic, Diagnostics, Admitted, tracer, owner),
			record(ExactHaxeRangeMap, SourceMaps, Admitted, tracer, owner),
			record(IntLiteral, Numeric, Admitted, semantic, owner),
			record(IntAddition, Numeric, Admitted, semantic, owner),
			record(InitializedIntLocal, ValuesCollections, Admitted, semantic, owner),
			record(IntEquality, ControlFlow, Admitted, semantic, owner),
			record(IfElse, ControlFlow, Admitted, semantic, owner),
			record(IntAssignment, ControlFlow, Admitted, semantic, owner),
			record(IntLessOrEqual, ControlFlow, Admitted, semantic, owner),
			record(WhileLoop, ControlFlow, Admitted, semantic, owner),
			record(IntArrayLiteral, ValuesCollections, Admitted, semantic, owner),
			record(ProvenIntArrayRead, ValuesCollections, Admitted, semantic, owner),
			record(RequiredIntParameters, CallsClosures, Admitted, semantic, owner),
			record(IntReturn, CallsClosures, Admitted, semantic, owner),
			record(StaticApplicationCall, CallsClosures, Admitted, semantic, owner),
			record(StringConcatenation, StringUnicode, Admitted, semantic, owner),
			record(StringEquality, StringUnicode, Admitted, semantic, owner),
			record(Utf8StringLiteralRoundTrip, StringUnicode, Admitted, semantic, owner),
			record(InstanceLayout, ModuleTypeLayout, UnsupportedOwned, "validator rejects instance methods and fields", owner),
			record(ArrayCollection, ValuesCollections, UnsupportedOwned,
				"general Array runtime behavior beyond fixed Int literals and proven reads is rejected", owner),
			record(Closure, CallsClosures, UnsupportedOwned, "validator rejects closure expressions", owner),
			record(TryThrowCatch, Exceptions, UnsupportedOwned, "validator rejects try, throw, and catch statements", owner),
			record(NullableValue, NullBehavior, UnsupportedOwned, "validator rejects null values", owner),
			record(HaxeStdlib, RuntimeStdlib, UnsupportedOwned, "no owned Haxe runtime or standard-library projection exists", owner),
			record(NumericEdgeSemantics, Numeric, UnverifiedOwned, "overflow, division, and modulo are not classified", owner),
			record(UnicodeRuntime, StringUnicode, UnverifiedOwned, "runtime Unicode operations are not classified", owner),
			record(CollectionOrdering, Ordering, UnverifiedOwned, "collection and object ordering are not classified", owner),
			record(PathEnvironment, PathEnvironmentFileSystemNetworkTimezone, UnverifiedOwned, "path and environment semantics are not classified", owner),
			record(FileSystem, PathEnvironmentFileSystemNetworkTimezone, UnverifiedOwned, "filesystem semantics are not classified", owner),
			record(Network, PathEnvironmentFileSystemNetworkTimezone, UnverifiedOwned, "network semantics are not classified", owner),
			record(Timezone, PathEnvironmentFileSystemNetworkTimezone, UnverifiedOwned, "timezone semantics are not classified", owner)
		];
	}

	public static function requireAdmitted(id:PhpSemanticCapabilityId):Void {
		for (entry in records()) {
			if (entry.id == id) {
				if (entry.state != Admitted) {
					throw "reflaxe.php internal capability is not admitted: " + id.value();
				}
				return;
			}
		}
		throw "reflaxe.php internal capability is not inventoried: " + id.value();
	}

	static function record(id:PhpSemanticCapabilityId, category:PhpSemanticCategory, state:PhpSemanticCapabilityState, evidence:String,
			owner:String):PhpSemanticCapabilityRecord {
		return {
			id: id,
			category: category,
			state: state,
			evidence: evidence,
			owner: owner
		};
	}
}
