package wordpresshx.cli.project.development;

import wordpresshx.cli.CliEventStream;
import wordpresshx.cli.ownership.OwnershipJson;
import wordpresshx.cli.project.development.DevelopmentPlan.DevelopmentService;

/** Redacted service lifecycle events. */
class DevelopmentEvents {
	final events:CliEventStream;

	public function new(events:CliEventStream) {
		this.events = events;
	}

	public function starting(service:DevelopmentService):Void {
		events.emit("service-starting", "service-start", "running", OwnershipJson.object([
			"serviceId" => service.id,
			"serviceKind" => service.kindName(),
			"processOwnership" => "owned",
			"readiness" => service.readinessName(),
			"timeoutMs" => service.readiness.timeoutMs
		]));
	}

	public function ready(service:DevelopmentService, url:String):Void {
		events.emit("service-ready", "service-readiness", "ready", OwnershipJson.object([
			"serviceId" => service.id,
			"serviceKind" => service.kindName(),
			"processOwnership" => "owned",
			"url" => url,
			"readiness" => service.readinessName(),
			"reload" => service.reloadName()
		]));
	}

	public function stopped(service:DevelopmentService, reason:String):Void {
		events.emit("service-stopped", "shutdown", "stopped", OwnershipJson.object([
			"serviceId" => service.id,
			"serviceKind" => service.kindName(),
			"processOwnership" => "owned",
			"reason" => reason
		]));
	}

	public function reload(service:DevelopmentService, url:String):Void {
		events.emit("reload-requested", "watching", "running", OwnershipJson.object([
			"serviceId" => service.id,
			"serviceKind" => service.kindName(),
			"url" => url,
			"reload" => service.reloadName(),
			"reason" => "complete ownership transaction published"
		]));
	}
}
