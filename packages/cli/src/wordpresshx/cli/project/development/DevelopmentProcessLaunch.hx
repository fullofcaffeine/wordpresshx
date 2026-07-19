package wordpresshx.cli.project.development;

import haxe.DynamicAccess;

/** Fully derived, no-shell launch and optional owned-resource cleanup. */
typedef DevelopmentProcessLaunch = {
	final executable:String;
	final arguments:Array<String>;
	final workingDirectory:String;
	final environment:DynamicAccess<String>;
	final cleanup:Null<(Void->Void)->Void>;
}
