package acme.site;

enum abstract DevServiceKind(String) from String to String {
	final WordPress = "wordpress";
	final NextJs = "nextjs";
}

typedef DevService = {
	final id:String;
	final kind:DevServiceKind;
	final preferredPort:Int;
	final readinessPath:String;
	final reload:String;
}

/**
	Synthetic typed authority for the ADR-016 consumer fixture. Production API
	names remain owned by the later site and CLI implementation beads.
**/
class Site {
	public static final projectId = "acme-observatory";
	public static final profile = "wp70-release";
	public static final development:Array<DevService> = [
		{
			id: "wordpress",
			kind: WordPress,
			preferredPort: 8888,
			readinessPath: "/wp-json/",
			reload: "full-page"
		},
		{
			id: "nextjs",
			kind: NextJs,
			preferredPort: 3000,
			readinessPath: "/",
			reload: "native-hmr"
		}
	];
}
