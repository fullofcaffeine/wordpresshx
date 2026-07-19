package wordpresshx.cli.project;

/** Closed compiler-collected definition for one native plugin artifact. */
class PluginPlan {
	public final slug:String;
	public final profile:String;
	public final name:String;
	public final description:String;
	public final version:String;
	public final author:String;
	public final license:String;
	public final namespace:String;
	public final sourcePath:String;
	public final startLine:Int;
	public final startColumn:Int;
	public final endLine:Int;
	public final endColumn:Int;
	public final privateTitleFilter:Null<PluginPrivateTitleFilter>;

	public function new(slug:String, profile:String, name:String, description:String, version:String, author:String, license:String, namespace:String,
			sourcePath:String, startLine:Int, startColumn:Int, endLine:Int, endColumn:Int, privateTitleFilter:Null<PluginPrivateTitleFilter>) {
		this.slug = slug;
		this.profile = profile;
		this.name = name;
		this.description = description;
		this.version = version;
		this.author = author;
		this.license = license;
		this.namespace = namespace;
		this.sourcePath = sourcePath;
		this.startLine = startLine;
		this.startColumn = startColumn;
		this.endLine = endLine;
		this.endColumn = endColumn;
		this.privateTitleFilter = privateTitleFilter;
	}
}
