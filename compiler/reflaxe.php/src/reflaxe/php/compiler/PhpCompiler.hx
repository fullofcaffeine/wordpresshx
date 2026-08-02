package reflaxe.php.compiler;

#if macro
import haxe.crypto.Sha256;
import haxe.io.Path;
import haxe.macro.Context;
import haxe.macro.Expr.Position;
import haxe.macro.Type;
import haxe.macro.TypedExprTools;
import reflaxe.GenericCompiler;
import reflaxe.data.ClassFuncData;
import reflaxe.data.ClassVarData;
import reflaxe.data.EnumOptionData;
import reflaxe.output.DataAndFileInfo;
import reflaxe.output.StringOrBytes;
import reflaxe.php.compiler.PhpArtifactManifestWriter.PhpCompilationArtifactKind;
import reflaxe.php.compiler.PhpArtifactManifestWriter.PhpCompilationArtifactRecord;
import reflaxe.php.compiler.PhpGeneratedOutputOwner.PhpOwnedGeneratedFile;
import reflaxe.php.compiler.PhpModulePlan.PhpModuleNode;
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

private typedef PhpLoweredTypeArtifact = {
	final identity:String;
	final path:String;
	final declaration:PhpClass;
	final dependencies:Array<String>;
	final position:Position;
}
#end

/** A staged compiler: callbacks collect typed classes, then a deterministic artifact graph is published. **/
class PhpCompiler extends GenericCompiler<PhpStagedOutput, PhpStagedOutput, PhpStagedOutput, PhpStagedOutput, PhpStagedOutput> {
	#if macro
	var config:PhpCompilerConfig;
	var sources:PhpSourceRegistry;
	var lowerer:PhpTypedAstLowerer;
	var loweredTypes:Array<PhpLoweredTypeArtifact> = [];
	var generatedFiles:Array<PhpOwnedGeneratedFile> = [];

	public function new(config:PhpCompilerConfig) {
		super();
		this.config = config;
	}

	override public function onCompileStart():Void {
		sources = new PhpSourceRegistry(config);
		lowerer = new PhpTypedAstLowerer(sources);
		loweredTypes = [];
		generatedFiles = [];
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
		loweredTypes.push({
			identity: PhpArtifactLayout.typeIdentity(classType.module, classType.name),
			path: PhpArtifactLayout.typePath(classType.module, classType.name),
			declaration: lowerer.lowerClass(classType, varFields, funcFields),
			dependencies: collectDependencies(classType, funcFields),
			position: classType.pos
		});
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
		final orderedTypes = orderLoweredTypes();
		final mainIdentity = PhpArtifactLayout.typeIdentity(mainClass.module, mainClass.name);
		if (!hasLoweredIdentity(mainIdentity)) {
			Context.fatalError("reflaxe.php selected main class did not produce an owned module artifact", mainClass.pos);
		}
		final generatorSha256 = generatorSourceSha256();
		final buildInputsSha256 = sources.buildInputsSha256();
		final writer = new PhpRangeMapWriter(new PhpRangeMapConfig("reflaxe.php-range-map.v1", "reflaxe.php.compiler", "0.0.0", generatorSha256,
			buildInputsSha256));
		final nextFiles:Array<PhpOwnedGeneratedFile> = [];
		final manifestRecords:Array<PhpCompilationArtifactRecord> = [];
		for (artifact in orderedTypes) {
			final file = new PhpFile(artifact.path, null, config.targetProfile.usesStrictTypes(), [PhpClassDeclaration(artifact.declaration)], []);
			final rendered = new PhpPrinter().printFile(file);
			final mapPath = artifact.path + ".haxe-map.json";
			final rangeMap = writer.write(rendered);
			nextFiles.push(new PhpOwnedGeneratedFile(artifact.path, rendered.source));
			nextFiles.push(new PhpOwnedGeneratedFile(mapPath, rangeMap));
			manifestRecords.push(new PhpCompilationArtifactRecord(ModuleArtifact, artifact.identity, artifact.path, digest(rendered.source), mapPath,
				digest(rangeMap), artifact.dependencies));
		}

		final mainRange = sources.range(mainClass.pos);
		final invokeMain = PhpMapped(PhpExprStmt(PhpStaticCall(lowerer.className(mainClass), "main", [])), mainRange,
			"entrypoint:"
			+ mainClass.module
			+ ":"
			+ mainClass.name, false);
		final bootstrapStatements:Array<PhpStmt> = [];
		for (artifact in orderedTypes) {
			bootstrapStatements.push(PhpRequireOnce(PhpBinop(".", PhpMagicConst("__DIR__"), PhpString("/" + artifact.path))));
		}
		bootstrapStatements.push(invokeMain);
		final bootstrapPath = "bootstrap.php";
		final bootstrapFile = new PhpFile(bootstrapPath, null, config.targetProfile.usesStrictTypes(), [], bootstrapStatements);
		final bootstrap = new PhpPrinter().printFile(bootstrapFile);
		final bootstrapMapPath = bootstrapPath + ".haxe-map.json";
		final bootstrapMap = writer.write(bootstrap);
		nextFiles.push(new PhpOwnedGeneratedFile(bootstrapPath, bootstrap.source));
		nextFiles.push(new PhpOwnedGeneratedFile(bootstrapMapPath, bootstrapMap));
		final loadOrder = orderedTypes.map(artifact -> artifact.path);
		manifestRecords.push(new PhpCompilationArtifactRecord(BootstrapArtifact, "entrypoint:" + mainIdentity, bootstrapPath, digest(bootstrap.source),
			bootstrapMapPath, digest(bootstrapMap), orderedTypes.map(artifact -> artifact.identity)));
		final manifest = PhpArtifactManifestWriter.write(config.targetProfile, generatorSha256, buildInputsSha256, mainIdentity, bootstrapPath, loadOrder,
			manifestRecords);
		nextFiles.push(new PhpOwnedGeneratedFile("reflaxe.php-artifacts.json", manifest));
		nextFiles.sort((left, right) -> compareText(left.path, right.path));
		generatedFiles = nextFiles;
	}

	override public function generateFilesManually():Void {
		if (output == null || output.outputDir == null || generatedFiles.length == 0) {
			Context.fatalError("reflaxe.php output was not prepared", Context.currentPos());
			return;
		}
		new PhpGeneratedOutputOwner(output.outputDir).publish(generatedFiles);
	}

	public function generateOutputIterator():Iterator<DataAndFileInfo<StringOrBytes>> {
		final empty = new Array<DataAndFileInfo<StringOrBytes>>();
		return empty.iterator();
	}

	function collectDependencies(classType:ClassType, funcFields:Array<ClassFuncData>):Array<String> {
		final dependencies = new Map<String, Bool>();
		final self = PhpArtifactLayout.typeIdentity(classType.module, classType.name);
		function visit(expression:TypedExpr):Void {
			switch (expression.expr) {
				case TField(_, FStatic(classRef, _)):
					final dependencyClass = classRef.get();
					if (sources.owns(dependencyClass.pos)) {
						final identity = PhpArtifactLayout.typeIdentity(dependencyClass.module, dependencyClass.name);
						if (identity != self) {
							dependencies.set(identity, true);
						}
					}
				case _:
			}
			TypedExprTools.iter(expression, visit);
		}
		for (functionData in funcFields) {
			if (functionData.expr != null) {
				visit(functionData.expr);
			}
		}
		final result = [for (identity in dependencies.keys()) identity];
		result.sort(compareText);
		return result;
	}

	function orderLoweredTypes():Array<PhpLoweredTypeArtifact> {
		final byIdentity = new Map<String, PhpLoweredTypeArtifact>();
		final nodes:Array<PhpModuleNode> = [];
		for (artifact in loweredTypes) {
			if (byIdentity.exists(artifact.identity)) {
				Context.fatalError("reflaxe.php received a duplicate module/type identity", artifact.position);
			}
			byIdentity.set(artifact.identity, artifact);
			nodes.push(new PhpModuleNode(artifact.identity, artifact.path, artifact.dependencies));
		}
		final orderedNodes = try {
			PhpModulePlan.order(nodes);
		} catch (message:String) {
			Context.fatalError(message, Context.currentPos());
			[];
		}
		final result:Array<PhpLoweredTypeArtifact> = [];
		for (node in orderedNodes) {
			final artifact = byIdentity.get(node.identity);
			if (artifact == null) {
				Context.fatalError("reflaxe.php internal module plan lost an artifact", Context.currentPos());
			} else {
				result.push(artifact);
			}
		}
		return result;
	}

	function hasLoweredIdentity(identity:String):Bool {
		for (artifact in loweredTypes) {
			if (artifact.identity == identity) {
				return true;
			}
		}
		return false;
	}

	static function digest(content:String):String {
		return Sha256.make(haxe.io.Bytes.ofString(content)).toHex().toLowerCase();
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
