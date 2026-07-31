package wordpresshx.cli.project.development;

import haxe.DynamicAccess;

/** Fully derived, no-shell launch and optional owned-resource cleanup. */
typedef DevelopmentProcessLaunch = {
	final executable:String;
	final arguments:Array<String>;
	final workingDirectory:String;
	final environment:DynamicAccess<String>;
	final ownership:DevelopmentProcessOwnership;
	final cleanup:Null<(Void->Void)->Void>;
}

/**
 * Selects the operating-system lifetime boundary for one launched service.
 *
 * External tools may create workers and watchers, so their complete process
 * group belongs to WordPressHx. A provider with a stronger native cleanup
 * transaction, such as Docker Compose, retains its direct-child boundary.
 */
enum DevelopmentProcessOwnership {
	DirectChild;
	OwnedProcessTree;
}
