package wordpress.hx.gutenberg.block._internal;

#if macro
import haxe.io.Path;
import haxe.macro.Context;
import haxe.macro.Expr;
import sys.FileSystem;
import wordpress.hx.gutenberg.block._internal.BlockInputs.fail;
import wordpress.hx.gutenberg.block._internal.BlockModel.BlockSession;

/** Compilation-local collector for typed block declarations. */
class BlockBuilder {
	static final PROFILE_DEFINE = "wordpress_hx_block_profile";
	static final ASSETS_DEFINE = "wordpress_hx_block_assets";
	static final OUTPUT_DEFINE = "wordpress_hx_block_output";
	static var generation = 0;
	static var active:Null<BlockSession>;

	public static function install():Expr {
		generation++;
		final position = Context.currentPos();
		final profilePath = inputPath(requiredDefine(PROFILE_DEFINE, position));
		final assetManifestPath = inputPath(requiredDefine(ASSETS_DEFINE, position));
		final outputRoot = outputPath(requiredDefine(OUTPUT_DEFINE, position), position);
		final profile = BlockInputs.profile(profilePath, position);
		final session:BlockSession = {
			generation: generation,
			profile: profile,
			profilePath: profilePath,
			assetManifestPath: assetManifestPath,
			outputRoot: outputRoot,
			assets: BlockInputs.assets(assetManifestPath, outputRoot, profile, position),
			drafts: [],
			finalized: false
		};
		active = session;
		final installedGeneration = generation;
		Context.onGenerate(_ -> {
			if (active != null && active.generation == installedGeneration && !active.finalized) {
				active.finalized = true;
				BlockEmitter.emit(active);
			}
		}, false);
		return macro null;
	}

	public static function define(attributeShape:Expr, options:Expr):Expr {
		final session = active;
		if (session == null || session.finalized) {
			return fail("WPX6000", "Block.define requires Block.install() and an active metadata compilation", options.pos);
		}
		final attributes = BlockAttributeDeriver.derive(attributeShape);
		session.drafts.push(BlockOptions.parse(session, attributes, options));
		return macro null;
	}

	static function requiredDefine(name:String, position:Position):String {
		final value = Context.definedValue(name);
		if (value == null || value == "" || value == "1") {
			return fail("WPX6000", "block compiler requires -D " + name + "=<path>", position);
		}
		return value;
	}

	static function inputPath(path:String):String {
		return FileSystem.fullPath(Path.isAbsolute(path) ? path : Path.join([Sys.getCwd(), path]));
	}

	static function outputPath(path:String, position:Position):String {
		final resolved = inputPath(path);
		final repositoryRoot = FileSystem.fullPath(Sys.getCwd());
		if (!FileSystem.exists(resolved) || !FileSystem.isDirectory(resolved)) {
			return fail("WPX6000", "block output root must be a pre-created staging directory", position);
		}
		if (resolved == repositoryRoot || resolved == Path.directory(repositoryRoot)) {
			return fail("WPX6000", "block compiler refuses a repository or parent directory as its staging root", position);
		}
		return resolved;
	}
}
#end
