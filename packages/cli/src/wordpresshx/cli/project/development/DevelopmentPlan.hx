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

	public static function digestServices(projectLockSha256:String, payloads:Array<JsonValue>):String {
		return CanonicalJson.digest(ObjectValue([
			{name: "projectLockSha256", value: StringValue(projectLockSha256)},
			{name: "services", value: ArrayValue(payloads)}
		]));
	}
}
