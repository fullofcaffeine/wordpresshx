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
	var BoolLiteral = "value.bool-literal";
	var IntAddition = "numeric.int-addition";
	var InitializedIntLocal = "value.initialized-int-local";
	var InitializedBoolLocal = "value.initialized-bool-local";
	var InitializedStringClosureLocal = "value.initialized-string-closure-local";
	var IntEquality = "control.int-equality";
	var BoolCondition = "control.bool-condition";
	var BoolParenthesizedGrouping = "control.bool-parenthesized-grouping";
	var BoolShortCircuitAnd = "control.bool-short-circuit-and";
	var BoolShortCircuitOr = "control.bool-short-circuit-or";
	var BoolNot = "control.bool-not";
	var IfElse = "control.if-else";
	var IntAssignment = "control.int-assignment";
	var IntLessOrEqual = "control.int-less-or-equal";
	var WhileLoop = "control.while";
	var InstanceLayout = "module.instance-layout";
	var PrivateInstanceStringField = "module.private-instance-string-field";
	var RequiredStringConstructor = "declaration.required-string-constructor";
	var RequiredStringInstanceMethod = "declaration.required-string-instance-method";
	var InitializedObjectLocal = "value.initialized-source-owned-object-local";
	var SourceOwnedConstructorCall = "call.source-owned-constructor";
	var SourceOwnedStringInstanceCall = "call.source-owned-string-instance-call";
	var RequiredStringClosureParameter = "call.required-non-null-string-closure-parameter";
	var StringClosureReturn = "call.non-null-string-closure-return";
	var ReadOnlyStringClosureCapture = "call.read-only-string-closure-capture";
	var StringClosureInvoke = "call.string-closure-invoke";
	var InstanceStringFieldRead = "value.instance-string-field-read";
	var InstanceStringFieldConstructorAssignment = "control.instance-string-field-constructor-assignment";
	var IntArrayLiteral = "collection.int-array-literal";
	var ProvenIntArrayRead = "collection.proven-int-array-read";
	var ArrayCollection = "collection.array";
	var RequiredIntParameters = "call.required-int-parameters";
	var RequiredBoolParameters = "call.required-non-null-bool-parameters";
	var RequiredStringParameters = "call.required-non-null-string-parameters";
	var IntReturn = "call.int-return";
	var BoolReturn = "call.non-null-bool-return";
	var StringReturn = "call.non-null-string-return";
	var StaticApplicationCall = "call.static-application-int-call";
	var StaticApplicationBoolCall = "call.static-application-bool-call";
	var StaticApplicationStringCall = "call.static-application-string-call";
	var Closure = "call.closure";
	var ThrowHaxeException = "exception.throw-haxe-exception";
	var CatchHaxeException = "exception.catch-haxe-exception";
	var CaughtHaxeExceptionMessage = "exception.caught-haxe-exception-message";
	var TryThrowCatch = "exception.try-throw-catch";
	var NullLiteral = "null.null-literal";
	var InitializedNullableStringLocal = "null.initialized-nullable-string-local";
	var RequiredNullableStringParameter = "call.required-nullable-string-parameter";
	var StaticApplicationNullableStringCall = "call.static-application-nullable-string-call";
	var NullableStringNullEquality = "null.nullable-string-equality";
	var NullableStringNullInequality = "null.nullable-string-inequality";
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
			record(RequiredStringConstructor, ModuleTypeLayout, Admitted, semantic, owner),
			record(RequiredStringInstanceMethod, ModuleTypeLayout, Admitted, semantic, owner),
			record(PrivateInstanceStringField, ModuleTypeLayout, Admitted, semantic, owner),
			record(StringLiteral, ValuesCollections, Admitted, semantic, owner),
			record(InitializedStringLocal, ValuesCollections, Admitted, semantic, owner),
			record(SysPrintlnString, CallsClosures, Admitted, semantic, owner),
			record(UnsupportedAstDiagnostic, Diagnostics, Admitted, tracer, owner),
			record(ExactHaxeRangeMap, SourceMaps, Admitted, tracer, owner),
			record(IntLiteral, Numeric, Admitted, semantic, owner),
			record(BoolLiteral, ValuesCollections, Admitted, semantic, owner),
			record(IntAddition, Numeric, Admitted, semantic, owner),
			record(InitializedIntLocal, ValuesCollections, Admitted, semantic, owner),
			record(InitializedBoolLocal, ValuesCollections, Admitted, semantic, owner),
			record(InitializedStringClosureLocal, ValuesCollections, Admitted, semantic, owner),
			record(InitializedObjectLocal, ValuesCollections, Admitted, semantic, owner),
			record(InstanceStringFieldRead, ValuesCollections, Admitted, semantic, owner),
			record(IntEquality, ControlFlow, Admitted, semantic, owner),
			record(BoolCondition, ControlFlow, Admitted, semantic, owner),
			record(BoolParenthesizedGrouping, ControlFlow, Admitted, semantic, owner),
			record(BoolShortCircuitAnd, ControlFlow, Admitted, semantic, owner),
			record(BoolShortCircuitOr, ControlFlow, Admitted, semantic, owner),
			record(BoolNot, ControlFlow, Admitted, semantic, owner),
			record(IfElse, ControlFlow, Admitted, semantic, owner),
			record(IntAssignment, ControlFlow, Admitted, semantic, owner),
			record(InstanceStringFieldConstructorAssignment, ControlFlow, Admitted, semantic, owner),
			record(IntLessOrEqual, ControlFlow, Admitted, semantic, owner),
			record(WhileLoop, ControlFlow, Admitted, semantic, owner),
			record(IntArrayLiteral, ValuesCollections, Admitted, semantic, owner),
			record(ProvenIntArrayRead, ValuesCollections, Admitted, semantic, owner),
			record(RequiredIntParameters, CallsClosures, Admitted, semantic, owner),
			record(RequiredBoolParameters, CallsClosures, Admitted, semantic, owner),
			record(RequiredStringParameters, CallsClosures, Admitted, semantic, owner),
			record(IntReturn, CallsClosures, Admitted, semantic, owner),
			record(BoolReturn, CallsClosures, Admitted, semantic, owner),
			record(StringReturn, CallsClosures, Admitted, semantic, owner),
			record(StaticApplicationCall, CallsClosures, Admitted, semantic, owner),
			record(StaticApplicationBoolCall, CallsClosures, Admitted, semantic, owner),
			record(StaticApplicationStringCall, CallsClosures, Admitted, semantic, owner),
			record(SourceOwnedConstructorCall, CallsClosures, Admitted, semantic, owner),
			record(SourceOwnedStringInstanceCall, CallsClosures, Admitted, semantic, owner),
			record(RequiredStringClosureParameter, CallsClosures, Admitted, semantic, owner),
			record(StringClosureReturn, CallsClosures, Admitted, semantic, owner),
			record(ReadOnlyStringClosureCapture, CallsClosures, Admitted, semantic, owner),
			record(StringClosureInvoke, CallsClosures, Admitted, semantic, owner),
			record(ThrowHaxeException, Exceptions, Admitted, semantic, owner),
			record(CatchHaxeException, Exceptions, Admitted, semantic, owner),
			record(CaughtHaxeExceptionMessage, Exceptions, Admitted, semantic, owner),
			record(NullLiteral, NullBehavior, Admitted, semantic, owner),
			record(InitializedNullableStringLocal, NullBehavior, Admitted, semantic, owner),
			record(RequiredNullableStringParameter, CallsClosures, Admitted, semantic, owner),
			record(StaticApplicationNullableStringCall, CallsClosures, Admitted, semantic, owner),
			record(NullableStringNullEquality, NullBehavior, Admitted, semantic, owner),
			record(NullableStringNullInequality, NullBehavior, Admitted, semantic, owner),
			record(StringConcatenation, StringUnicode, Admitted, semantic, owner),
			record(StringEquality, StringUnicode, Admitted, semantic, owner),
			record(Utf8StringLiteralRoundTrip, StringUnicode, Admitted, semantic, owner),
			record(InstanceLayout, ModuleTypeLayout, UnsupportedOwned,
				"only a non-inherited private-String-field constructor and String instance-method slice is admitted", owner),
			record(ArrayCollection, ValuesCollections, UnsupportedOwned,
				"general Array runtime behavior beyond fixed Int literals and proven reads is rejected", owner),
			record(Closure, CallsClosures, UnsupportedOwned, "validator rejects closure expressions", owner),
			record(TryThrowCatch, Exceptions, UnsupportedOwned,
				"only one immediate new haxe.Exception throw, exact catch, and caught-message read are admitted", owner),
			record(NullableValue, NullBehavior, UnsupportedOwned,
				"only explicit Null<String> locals, required parameters, source-owned calls, and local ==/!= null checks are admitted", owner),
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
