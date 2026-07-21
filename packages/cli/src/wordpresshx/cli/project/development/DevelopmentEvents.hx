package wordpresshx.cli.project.development;

import wordpresshx.cli.CliEventStream;
import wordpresshx.cli.CliJson;
import wordpresshx.cli.project.development.DevelopmentPlan.DevelopmentService;

/** Redacted service lifecycle events. */
class DevelopmentEvents {
	final events:CliEventStream;

	public function new(events:CliEventStream) {
		this.events = events;
	}

	public function starting(service:DevelopmentService):Void {
		events.emit("service-starting", "service-start", "running", CliJson.object([
			"serviceId" => CliJson.text(service.id),
			"serviceKind" => CliJson.text(service.kindName()),
			"processOwnership" => CliJson.text("owned"),
			"readiness" => CliJson.text(service.readinessName()),
			"timeoutMs" => CliJson.number(service.readiness.timeoutMs)
		]));
	}

	public function ready(service:DevelopmentService, url:String):Void {
		events.emit("service-ready", "service-readiness", "ready", CliJson.object([
			"serviceId" => CliJson.text(service.id),
			"serviceKind" => CliJson.text(service.kindName()),
			"processOwnership" => CliJson.text("owned"),
			"url" => CliJson.text(url),
			"readiness" => CliJson.text(service.readinessName()),
			"reload" => CliJson.text(service.reloadName())
		]));
	}

	public function stopped(service:DevelopmentService, reason:String):Void {
		events.emit("service-stopped", "shutdown", "stopped", CliJson.object([
			"serviceId" => CliJson.text(service.id),
			"serviceKind" => CliJson.text(service.kindName()),
			"processOwnership" => CliJson.text("owned"),
			"reason" => CliJson.text(reason)
		]));
	}

	public function reload(service:DevelopmentService, url:String):Void {
		events.emit("reload-requested", "watching", "running", CliJson.object([
			"serviceId" => CliJson.text(service.id),
			"serviceKind" => CliJson.text(service.kindName()),
			"url" => CliJson.text(url),
			"reload" => CliJson.text(service.reloadName()),
			"reason" => CliJson.text("complete ownership transaction published")
		]));
	}
}
