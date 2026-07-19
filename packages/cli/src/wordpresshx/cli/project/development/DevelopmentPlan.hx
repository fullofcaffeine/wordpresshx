package wordpresshx.cli.project.development;

import wordpresshx.cli.closedjson.CanonicalJson;
import wordpresshx.cli.closedjson.JsonValue;

enum DevelopmentServiceKind {
	External;
	WordPress;
}

enum DevelopmentReadinessKind {
	Http;
	Log;
	Process;
	Tcp;
}

enum DevelopmentReloadKind {
	FullPage;
	NoReload;
}

typedef DevelopmentCommand = {
	final component:String;
	final executable:String;
	final arguments:Array<String>;
}

typedef DevelopmentPort = {
	final preferred:Int;
	final strict:Bool;
}

typedef DevelopmentReadiness = {
	final kind:DevelopmentReadinessKind;
	final path:String;
	final text:String;
	final timeoutMs:Int;
	final intervalMs:Int;
}

typedef DevelopmentRestart = {
	final maxAttempts:Int;
	final backoffMs:Int;
}

typedef DevelopmentUrl = {
	final scheme:String;
	final path:String;
}

class DevelopmentService {
	public final id:String;
	public final kind:DevelopmentServiceKind;
	public final dependsOn:Array<String>;
	public final workingDirectory:String;
	public final command:Null<DevelopmentCommand>;
	public final environment:Array<String>;
	public final port:DevelopmentPort;
	public final readiness:DevelopmentReadiness;
	public final restart:DevelopmentRestart;
	public final url:DevelopmentUrl;
	public final reload:DevelopmentReloadKind;

	public function new(id:String, kind:DevelopmentServiceKind, dependsOn:Array<String>, workingDirectory:String, command:Null<DevelopmentCommand>,
			environment:Array<String>, port:DevelopmentPort, readiness:DevelopmentReadiness, restart:DevelopmentRestart, url:DevelopmentUrl,
			reload:DevelopmentReloadKind) {
		this.id = id;
		this.kind = kind;
		this.dependsOn = dependsOn;
		this.workingDirectory = workingDirectory;
		this.command = command;
		this.environment = environment;
		this.port = port;
		this.readiness = readiness;
		this.restart = restart;
		this.url = url;
		this.reload = reload;
	}

	public function kindName():String {
		return switch kind {
			case External: "external";
			case WordPress: "wordpress";
		};
	}

	public function readinessName():String {
		return switch readiness.kind {
			case Http: "http";
			case Log: "log";
			case Process: "process";
			case Tcp: "tcp";
		};
	}

	public function reloadName():String {
		return switch reload {
			case FullPage: "full-page";
			case NoReload: "none";
		};
	}
}

class DevelopmentPlan {
	public final serviceDigest:String;
	public final services:Array<DevelopmentService>;

	public function new(serviceDigest:String, services:Array<DevelopmentService>) {
		this.serviceDigest = serviceDigest;
		this.services = services;
	}

	public static function empty(projectLockSha256:String):DevelopmentPlan {
		return new DevelopmentPlan(digestServices(projectLockSha256, []), []);
	}

	public static function forPlugin(projectLockSha256:String):DevelopmentPlan {
		final payload = ObjectValue([
			{name: "command", value: NullValue},
			{name: "dependsOn", value: ArrayValue([])},
			{name: "environment", value: ArrayValue([])},
			{
				name: "port",
				value: ObjectValue([
					{name: "preferred", value: NumberValue("8888")},
					{name: "strict", value: BoolValue(false)}
				])
			},
			{
				name: "readiness",
				value: ObjectValue([
					{name: "intervalMs", value: NumberValue("100")},
					{name: "kind", value: StringValue("http")},
					{name: "path", value: StringValue("/wp-json/")},
					{name: "text", value: StringValue("WORDPRESSHX_DEV_READY")},
					{name: "timeoutMs", value: NumberValue("240000")}
				])
			},
			{name: "reload", value: StringValue("full-page")},
			{
				name: "restart",
				value: ObjectValue([
					{name: "backoffMs", value: NumberValue("250")},
					{name: "maxAttempts", value: NumberValue("1")}
				])
			},
			{name: "serviceId", value: StringValue("wordpress")},
			{name: "serviceKind", value: StringValue("wordpress")},
			{
				name: "url",
				value: ObjectValue([
					{name: "path", value: StringValue("/")},
					{name: "scheme", value: StringValue("http")}
				])
			},
			{name: "workingDirectory", value: StringValue(".")}
		]);
		final service = new DevelopmentService("wordpress", WordPress, [], ".", null, [], {
			preferred: 8888,
			strict: false
		}, {
			kind: Http,
			path: "/wp-json/",
			text: "WORDPRESSHX_DEV_READY",
			timeoutMs: 240000,
			intervalMs: 100
		}, {
			maxAttempts: 1,
			backoffMs: 250
		}, {
			scheme: "http",
			path: "/"
		}, FullPage);
		return new DevelopmentPlan(digestServices(projectLockSha256, [payload]), [service]);
	}

	public static function digestServices(projectLockSha256:String, payloads:Array<JsonValue>):String {
		return CanonicalJson.digest(ObjectValue([
			{name: "projectLockSha256", value: StringValue(projectLockSha256)},
			{name: "services", value: ArrayValue(payloads)}
		]));
	}
}
