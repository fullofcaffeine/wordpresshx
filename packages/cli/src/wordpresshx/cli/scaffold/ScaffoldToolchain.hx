package wordpresshx.cli.scaffold;

import wordpresshx.cli.Content;
import wordpresshx.cli.closedjson.CanonicalJson;
import wordpresshx.cli.closedjson.JsonValue;

private typedef ScaffoldComponentDefinition = {
	final id:String;
	final role:String;
	final version:String;
	final source:String;
	final identity:String;
}

/** Exact pre-release component closure used by the repository consumer fixture. */
class ScaffoldToolchain {
	public static function lock(projectId:String, profile:String, config:JsonValue, manifestPath:String, manifestContent:String, lockfilePath:String,
			lockfileContent:String):String {
		final fields = lockFields(projectId, profile, config, manifestPath, manifestContent, lockfilePath, lockfileContent);
		final material = ScaffoldJson.object(fields);
		final digest = CanonicalJson.digest(material);
		fields.insert(3, ScaffoldJson.field("lockDigest", ScaffoldJson.text(digest)));
		return ScaffoldJson.document(ScaffoldJson.object(fields), false);
	}

	static function lockFields(projectId:String, profile:String, config:JsonValue, manifestPath:String, manifestContent:String, lockfilePath:String,
			lockfileContent:String):Array<wordpresshx.cli.closedjson.JsonValue.JsonField> {
		return [
			ScaffoldJson.field("schema", ScaffoldJson.text("wordpress-hx.project-lock.v1")),
			ScaffoldJson.field("canonicalization", ScaffoldJson.text("wordpress-hx.canonical-json.v1")),
			ScaffoldJson.field("lockDigestAlgorithm", ScaffoldJson.text("sha256-canonical-json-without-lockDigest-v1")),
			ScaffoldJson.field("generatedBy", ScaffoldJson.object([
				ScaffoldJson.field("sdkVersion", ScaffoldJson.text("0.0.0")),
				ScaffoldJson.field("cliVersion", ScaffoldJson.text("0.0.0"))
			])),
			ScaffoldJson.field("project", ScaffoldJson.object([
				ScaffoldJson.field("id", ScaffoldJson.text(projectId)),
				ScaffoldJson.field("configPath", ScaffoldJson.text("wordpress-hx.json")),
				ScaffoldJson.field("configSemanticSha256", ScaffoldJson.text(CanonicalJson.digest(config)))
			])),
			ScaffoldJson.field("profile",
				ScaffoldJson.object([
					ScaffoldJson.field("id", ScaffoldJson.text(profile)),
					ScaffoldJson.field("catalogRevision", ScaffoldJson.text("wp70-release/catalog-v1")),
					ScaffoldJson.field("catalogSha256", ScaffoldJson.text("530a1581d07e7509fb68f7da5b53575009ed4a94280513efd82a8c99622d9d61"))
				])),
			ScaffoldJson.field("components", ScaffoldJson.array([for (definition in definitions()) component(definition)])),
			ScaffoldJson.field("packageGraph", ScaffoldJson.object([
				ScaffoldJson.field("manager", ScaffoldJson.text("npm")),
				ScaffoldJson.field("version", ScaffoldJson.text("10.9.2")),
				ScaffoldJson.field("manifest", packageFile(manifestPath, manifestContent)),
				ScaffoldJson.field("lockfile", packageFile(lockfilePath, lockfileContent)),
				ScaffoldJson.field("lifecycleScriptsAllowed", ScaffoldJson.boolean(false))
			]))
		];
	}

	static function packageFile(path:String, content:String):JsonValue {
		return ScaffoldJson.object([
			ScaffoldJson.field("path", ScaffoldJson.text(path)),
			ScaffoldJson.field("sha256", ScaffoldJson.text(Content.digest(content)))
		]);
	}

	static function component(definition:ScaffoldComponentDefinition):JsonValue {
		final fields = [
			ScaffoldJson.field("id", ScaffoldJson.text(definition.id)),
			ScaffoldJson.field("role", ScaffoldJson.text(definition.role)),
			ScaffoldJson.field("version", ScaffoldJson.text(definition.version)),
			ScaffoldJson.field("source", ScaffoldJson.text(definition.source)),
			ScaffoldJson.field("identity", ScaffoldJson.text(definition.identity))
		];
		final digest = CanonicalJson.digest(ScaffoldJson.object(fields));
		fields.push(ScaffoldJson.field("lockEntrySha256", ScaffoldJson.text(digest)));
		return ScaffoldJson.object(fields);
	}

	static function definitions():Array<ScaffoldComponentDefinition> {
		return [
			{
				id: "compiler.genes",
				role: "compiler",
				version: "1.36.3",
				source: "git-source",
				identity: "git:https://github.com/fullofcaffeine/genes-ts@c59ecb361fd91418584487c2138bae8d3d3a3961#tree=be1a96453ac97e6f80916b415deff0d0ad3f18a6"
			},
			{
				id: "compiler.haxe",
				role: "compiler",
				version: "4.3.7",
				source: "git-source",
				identity: "git:https://github.com/HaxeFoundation/haxe@e0b355c6be312c1b17382603f018cf52522ec651#tree=55d2c4c59ed55c52fa0660e2fe385081a94b23d1"
			},
			{
				id: "compiler.reflaxe-php",
				role: "compiler",
				version: "0.0.0",
				source: "co-located",
				identity: "sdk:wordpress-hx@0.0.0/compiler/reflaxe.php#sha256=cf0fc152f4fe09b8a9eb92f6b9f4c1f1591ab938531d6241c245ab11a75532f6"
			},
			{
				id: "runtime.node",
				role: "runtime",
				version: "22.17.0",
				source: "oci-image",
				identity: "docker.io/library/node@sha256:b04ce4ae4e95b522112c2e5c52f781471a5cbc3b594527bcddedee9bc48c03a0"
			},
			{
				id: "sdk.wordpress-hx",
				role: "sdk",
				version: "0.0.0",
				source: "co-located",
				identity: "repository:wordpresshx@fixture#toolchain-lock-sha256=f76230a6e27154d9ffc467362a0a75c51b633a6aa59bf696df6ab5f15e872785"
			},
			{
				id: "tool.lix",
				role: "dependency-manager",
				version: "15.12.4",
				source: "npm-release",
				identity: "npm:lix@15.12.4#sha256=4f2257276aba9f552b1b35237d33fbc1a0898039d8105ed6e8d1468e6c53a2fa"
			},
			{
				id: "tool.npm",
				role: "package-manager",
				version: "10.9.2",
				source: "oci-image",
				identity: "docker.io/library/node@sha256:b04ce4ae4e95b522112c2e5c52f781471a5cbc3b594527bcddedee9bc48c03a0#npm=10.9.2"
			},
			{
				id: "tool.wordpress-scripts",
				role: "build-tool",
				version: "31.5.0",
				source: "npm-release",
				identity: "npm:@wordpress/scripts@31.5.0#integrity=sha512-7OS5bpHtnuagG8k9q9BdilHjhQ0MLhY0ypDgnRom5WlgPBshM/SUaF9bQLDnSDeasiD/bIgaDmoxWkfVZ4qSPQ=="
			}
		];
	}
}
