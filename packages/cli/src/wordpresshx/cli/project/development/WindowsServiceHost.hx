package wordpresshx.cli.project.development;

import js.node.Fs;
import js.node.Path;
import js.node.child_process.ChildProcess as NodeChildProcess;
import wordpresshx.cli.CliFailure;

/**
 * Typed protocol for the packaged Win32 Job Object host.
 *
 * The native helper is a narrow operating-system adapter: it owns a private
 * console group, creates the user process suspended, assigns it to its owned
 * Job, and resumes it only after the lifetime boundary exists. Haxe retains
 * launch policy and stop timing.
 */
class WindowsServiceHost {
	public static inline final GRACEFUL_STOP = "graceful";
	public static inline final FORCE_STOP = "force";
	static inline final HELPER_NAME = "wphx-windows-service-host.exe";

	public static function executable(entryPath:String):String {
		final candidate = Path.join(Path.dirname(Path.resolve(entryPath)), "native", HELPER_NAME);
		if (!Fs.existsSync(candidate) || !Fs.lstatSync(candidate).isFile()) {
			throw new CliFailure("WPHX2326", "the packaged Windows Job Object service host is missing", 7, "service-start", null,
				["Reinstall the exact WordPressHx CLI package for this Windows architecture."]);
		}
		return candidate;
	}

	public static function arguments(executable:String, payloadArguments:Array<String>):Array<String> {
		return [executable].concat(payloadArguments);
	}

	public static function send(child:NodeChildProcess, command:String):Bool {
		return child.stdin.write(command + "\n");
	}
}
