package reflaxe.php.compiler;

#if macro
import haxe.crypto.Sha256;
import haxe.io.Path;
import haxe.macro.Context;
import haxe.macro.Type;
import reflaxe.GenericCompiler;
import reflaxe.data.ClassFuncData;
import reflaxe.data.ClassVarData;
import reflaxe.data.EnumOptionData;
import reflaxe.output.DataAndFileInfo;
import reflaxe.output.StringOrBytes;
import reflaxe.php.ir.PhpClass;
import reflaxe.php.ir.PhpDeclaration;
import reflaxe.php.ir.PhpExpr;
import reflaxe.php.ir.PhpFile;
import reflaxe.php.ir.PhpStmt;
import reflaxe.php.map.PhpRangeMapConfig;
import reflaxe.php.map.PhpRangeMapWriter;
import reflaxe.php.print.PhpPrinter;
import reflaxe.php.print.PhpRenderedFile;
import sys.FileSystem;
import sys.io.File;
#end

#if macro
enum PhpStagedOutput {
	StagedOutput;
}
#end

/** A staged compiler: callbacks collect typed classes, then one deterministic PHP file is emitted. **/
class PhpCompiler extends GenericCompiler<PhpStagedOutput, PhpStagedOutput, PhpStagedOutput, PhpStagedOutput, PhpStagedOutput> {
	#if macro
	var config:PhpCompilerConfig;
	var sources:PhpSourceRegistry;
	var lowerer:PhpTypedAstLowerer;
	var loweredClasses:Array<PhpClass> = [];
	var rendered:Null<PhpRenderedFile> = null;
	var rangeMap:Null<String> = null;

	public function new(config:PhpCompilerConfig) {
		super();
		this.config = config;
	}

	override public function onCompileStart():Void {
		sources = new PhpSourceRegistry(config);
		lowerer = new PhpTypedAstLowerer(sources);
		loweredClasses = [];
		rendered = null;
		rangeMap = null;
	}

	override public function shouldGenerateClass(classType:ClassType):Bool {
		return sources.owns(classType.pos) && super.shouldGenerateClass(classType);
	}

	override public function shouldGenerateEnum(enumType:EnumType):Bool {
		if (sources.owns(enumType.pos)) {
			Context.fatalError("reflaxe.php tracer does not yet support application enums", enumType.pos);
		}
		return false;
	}

	public function compileClassImpl(classType:ClassType, varFields:Array<ClassVarData>, funcFields:Array<ClassFuncData>):Null<PhpStagedOutput> {
		loweredClasses.push(lowerer.lowerClass(classType, varFields, funcFields));
		return null;
	}

	public function compileEnumImpl(enumType:EnumType, options:Array<EnumOptionData>):Null<PhpStagedOutput> {
		return null;
	}

	public function compileExpressionImpl(expression:TypedExpr, topLevel:Bool):Null<PhpStagedOutput> {
		return null;
	}

	override public function onCompileEnd():Void {
		PhpSemanticCapabilities.requireAdmitted(ExactHaxeRangeMap);
		final mainModule = getMainModule();
		final mainClass = switch (mainModule) {
			case TClassDecl(classRef): classRef.get();
			case _:
				Context.fatalError("reflaxe.php requires a Haxe-selected static main class", Context.currentPos());
				return;
		}
		if (!sources.owns(mainClass.pos)) {
			Context.fatalError("reflaxe.php selected main class is outside reflaxe_php_source_root", mainClass.pos);
		}
		final declarations = loweredClasses.map(value -> PhpClassDeclaration(value));
		final mainRange = sources.range(mainClass.pos);
		final invokeMain = PhpMapped(PhpExprStmt(PhpStaticCall(lowerer.className(mainClass), "main", [])), mainRange,
			"entrypoint:"
			+ mainClass.module
			+ ":"
			+ mainClass.name, false);
		final file = new PhpFile("main.php", null, true, declarations, [invokeMain]);
		final produced = new PhpPrinter().printFile(file);
		final writer = new PhpRangeMapWriter(new PhpRangeMapConfig("reflaxe.php-range-map.v1", "reflaxe.php.compiler", "0.0.0", generatorSourceSha256(),
			sources.buildInputsSha256()));
		rendered = produced;
		rangeMap = writer.write(produced);
	}

	override public function generateFilesManually():Void {
		if (output == null || rendered == null || rangeMap == null) {
			Context.fatalError("reflaxe.php output was not prepared", Context.currentPos());
			return;
		}
		output.saveFile("main.php", rendered.source);
		output.saveFile("main.php.haxe-map.json", rangeMap);
	}

	public function generateOutputIterator():Iterator<DataAndFileInfo<StringOrBytes>> {
		final empty = new Array<DataAndFileInfo<StringOrBytes>>();
		return empty.iterator();
	}

	function generatorSourceSha256():String {
		final compilerFile = Context.resolvePath("reflaxe/php/compiler/PhpCompiler.hx");
		final sourceRoot = Path.directory(Path.directory(compilerFile));
		final files = new Array<{logical:String, full:String}>();
		collectGeneratorSources(sourceRoot, "", files);
		files.sort((left, right) -> compareText(left.logical, right.logical));
		final transcript = files.map(file -> "reflaxe/php/" + file.logical + "\n" + File.getContent(file.full) + "\n").join("");
		return Sha256.make(haxe.io.Bytes.ofString(transcript)).toHex().toLowerCase();
	}

	function collectGeneratorSources(root:String, relative:String, files:Array<{logical:String, full:String}>):Void {
		final directory = relative.length == 0 ? root : Path.join([root, relative]);
		final entries = FileSystem.readDirectory(directory);
		entries.sort(compareText);
		for (entry in entries) {
			final logical = relative.length == 0 ? entry : relative + "/" + entry;
			final full = Path.join([root, logical]);
			if (FileSystem.isDirectory(full)) {
				collectGeneratorSources(root, logical, files);
			} else if (StringTools.endsWith(entry, ".hx")) {
				files.push({logical: logical, full: full});
			}
		}
	}

	static function compareText(left:String, right:String):Int {
		return left < right ? -1 : left > right ? 1 : 0;
	}
	#end
}
