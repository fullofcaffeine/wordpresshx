package wordpresshx.cli.project;

/** Closed ownership classification for generated plugin files. */
enum abstract PluginArtifactLane(String) {
	final PublicNative = "public-native";
	final PrivateRuntime = "private-stock-haxe-runtime";
	final PrivateClassmap = "private-classmap";
	final PrivateManifest = "private-runtime-manifest";

	public inline function label():String {
		return this;
	}
}
