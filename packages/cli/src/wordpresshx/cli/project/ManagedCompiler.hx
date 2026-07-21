package wordpresshx.cli.project;

import haxe.Timer;
import js.Syntax;
import js.node.Buffer;
import js.node.ChildProcess;
import js.node.Fs;
import js.node.Net;
import js.node.Path;
import js.node.child_process.ChildProcess as SpawnedProcess;
import js.node.child_process.ChildProcess.ChildProcessEvent;
import js.node.net.Server.ServerEvent;
import wordpresshx.cli.NodeGlobals;
import wordpresshx.cli.project.ProjectJson as OwnershipJson;

/** Disposable project-local Haxe wait server with an exact compatibility lease. **/
class ManagedCompiler {
	static inline final START_TIMEOUT_MS = 3000;
	static inline final STOP_TIMEOUT_MS = 1500;

	final warning:String->Void;
	var child:Null<SpawnedProcess>;
	var port:Null<Int>;
	var compatibilityDigest:Null<String>;
	var fallbackDigest:Null<String>;
	var cookiePath:Null<String>;
	var cookieBytes:Null<Buffer>;
	var runtimePath:Null<String>;
	var runtimeCreated = false;
	var ready = false;
	var stopping = false;
	var childExited = false;
	var closed = false;

	public function new(warning:String->Void) {
		this.warning = warning;
	}

	/** Callback arguments are cache available and newly started. **/
	public function ensure(context:ProjectContext, callback:Bool->Bool->Void):Void {
		final digest = serverDigest(context);
		if (closed) {
			callback(false, false);
			return;
		}
		if (ready && compatibilityDigest == digest && child != null && port != null) {
			callback(true, false);
			return;
		}
		if (fallbackDigest == digest) {
			callback(false, false);
			return;
		}
		final begin = () -> start(context, digest, callback);
		if (child != null) {
			stopOwned(begin);
		} else {
			begin();
		}
	}

	public function typeProject(context:ProjectContext):Void {
		if (!ready || child == null || port == null || compatibilityDigest != serverDigest(context)) {
			CompilerRunner.typeProject(context);
			return;
		}
		try {
			CompilerRunner.typeProjectWithServer(context, port);
		} catch (failure:haxe.Exception) {
			if (CompilerRunner.probeServer(context, port)) {
				throw failure;
			}
			warning("the owned Haxe cache stopped responding; this build is using direct compilation");
			abandon();
			CompilerRunner.typeProject(context);
		}
	}

	public function shutdown(callback:Void->Void):Void {
		closed = true;
		stopOwned(callback);
	}

	public inline function ownsServer():Bool {
		return child != null;
	}

	function start(context:ProjectContext, digest:String, callback:Bool->Bool->Void):Void {
		if (!claimLease(context)) {
			fallbackDigest = digest;
			callback(false, false);
			return;
		}
		reservePort(selected -> {
			if (selected == null || closed) {
				fallback(context, digest, callback, "could not reserve an isolated loopback port for the Haxe cache");
				return;
			}
			spawnServer(context, selected, digest, callback);
		});
	}

	function spawnServer(context:ProjectContext, selected:Int, digest:String, callback:Bool->Bool->Void):Void {
		var spawned:SpawnedProcess;
		try {
			spawned = ChildProcess.spawn("haxe", ["--wait", Std.string(selected)], {
				cwd: context.bootstrap.root,
				stdio: "ignore"
			});
		} catch (_:haxe.Exception) {
			fallback(context, digest, callback, "could not start the exact project Haxe cache");
			return;
		}
		child = spawned;
		port = selected;
		compatibilityDigest = digest;
		childExited = false;
		spawned.once(ChildProcessEvent.Error, _ -> childExited = true);
		spawned.once(ChildProcessEvent.Exit, (_:Int, _:String) -> {
			childExited = true;
			if (ready && !stopping && child == spawned) {
				warning("the owned Haxe cache exited; the next rebuild will start a replacement or compile directly");
				cleanupLease();
				child = null;
				port = null;
				compatibilityDigest = null;
				ready = false;
			}
		});

		final startedAt = Date.now().getTime();
		var probe:Void->Void = null;
		probe = () -> {
			if (closed || child != spawned || childExited) {
				fallback(context, digest, callback, "the project Haxe cache exited before readiness");
				return;
			}
			if (CompilerRunner.probeServer(context, selected)) {
				try {
					writeLease(context, selected, digest, spawned.pid);
					ready = true;
					fallbackDigest = null;
					callback(true, true);
				} catch (_:haxe.Exception) {
					fallback(context, digest, callback, "could not authenticate the project-local Haxe cache lease");
				}
				return;
			}
			if (Date.now().getTime() - startedAt >= START_TIMEOUT_MS) {
				fallback(context, digest, callback, "the project Haxe cache did not become ready within the bounded startup window");
				return;
			}
			Timer.delay(probe, 40);
		};
		Timer.delay(probe, 20);
	}

	function fallback(context:ProjectContext, digest:String, callback:Bool->Bool->Void, message:String):Void {
		fallbackDigest = digest;
		warning(message + "; this development session will compile directly");
		if (child != null) {
			stopOwned(() -> callback(false, false));
		} else {
			cleanupLease();
			callback(false, false);
		}
	}

	function reservePort(callback:Null<Int>->Void):Void {
		final reservation = Net.createServer();
		var settled = false;
		reservation.once(ServerEvent.Error, _ -> {
			if (!settled) {
				settled = true;
				callback(null);
			}
		});
		reservation.listen(0, "127.0.0.1", () -> {
			if (settled) {
				return;
			}
			final selected = reservation.address().port;
			reservation.close(() -> {
				if (!settled) {
					settled = true;
					callback(selected);
				}
			});
		});
	}

	function claimLease(context:ProjectContext):Bool {
		final runtime = runtimeRoot(context);
		cookiePath = Path.join(runtime, "compiler-server.json");
		if (!Fs.existsSync(cookiePath)) {
			return true;
		}
		try {
			final existingBytes = Fs.readFileSync(cookiePath);
			final existing = OwnershipJson.parseCanonical(existingBytes, "compiler server lease");
			if (ProjectContract.string(existing, "schema", "compiler server lease") != "wordpress-hx.compiler-server-lease.v1"
				|| ProjectContract.string(existing, "projectRootDigest", "compiler server lease") != rootDigest(context)) {
				warning("the project Haxe cache lease is malformed or belongs to a moved project; direct compilation is safer");
				return false;
			}
			final ownerPid = ProjectContract.integer(existing, "ownerPid", "compiler server lease");
			if (processAlive(ownerPid)) {
				warning("another live development command owns the project Haxe cache lease; this session will compile directly");
				return false;
			}
			Fs.unlinkSync(cookiePath);
			return true;
		} catch (_:haxe.Exception) {
			warning("the project Haxe cache lease could not be authenticated; this session will compile directly");
			return false;
		}
	}

	function writeLease(context:ProjectContext, selected:Int, digest:String, serverPid:Int):Void {
		if (cookiePath == null) {
			throw "compiler lease path is unavailable";
		}
		final document = OwnershipJson.object([
			"schema" => "wordpress-hx.compiler-server-lease.v1",
			"compatibilityDigest" => digest,
			"ownerPid" => NodeGlobals.process().pid,
			"port" => selected,
			"processOwnership" => "owned",
			"projectRootDigest" => rootDigest(context),
			"serverPid" => serverPid
		]);
		cookieBytes = OwnershipJson.encodeDocument(document);
		Fs.writeFileSync(cookiePath, cookieBytes, {flag: "wx", mode: 0x180});
	}

	function runtimeRoot(context:ProjectContext):String {
		final state = ProjectFiles.requireDirectory(context.bootstrap.root, context.bootstrap.stateRoot, "project state root", "compiler-server");
		final runtime = Path.join(state, "runtime");
		if (!Fs.existsSync(runtime)) {
			Fs.mkdirSync(runtime, 0x1c0);
			runtimeCreated = true;
		} else {
			final stats = Fs.lstatSync(runtime);
			if (stats.isSymbolicLink() || !stats.isDirectory()) {
				throw "compiler runtime root is not a real directory";
			}
		}
		runtimePath = runtime;
		return runtime;
	}

	function stopOwned(callback:Void->Void):Void {
		final current = child;
		if (current == null) {
			cleanupLease();
			clearServer();
			callback();
			return;
		}
		stopping = true;
		var completed = false;
		var killTimer:Null<Timer> = null;
		final finish = () -> {
			if (completed) {
				return;
			}
			completed = true;
			if (killTimer != null) {
				killTimer.stop();
			}
			cleanupLease();
			clearServer();
			callback();
		};
		current.once(ChildProcessEvent.Close, (_:Int, _:String) -> finish());
		try {
			current.kill("SIGTERM");
		} catch (_:haxe.Exception) {
			finish();
			return;
		}
		killTimer = Timer.delay(() -> {
			if (!completed) {
				try {
					current.kill("SIGKILL");
				} catch (_:haxe.Exception) {}
				Timer.delay(finish, 50);
			}
		}, STOP_TIMEOUT_MS);
	}

	function abandon():Void {
		final current = child;
		cleanupLease();
		clearServer();
		if (current != null) {
			try {
				current.kill("SIGTERM");
			} catch (_:haxe.Exception) {}
		}
	}

	function cleanupLease():Void {
		if (cookiePath != null && cookieBytes != null && Fs.existsSync(cookiePath)) {
			try {
				final current = Fs.readFileSync(cookiePath);
				if (OwnershipJson.digest(current) == OwnershipJson.digest(cookieBytes)) {
					Fs.unlinkSync(cookiePath);
				}
			} catch (_:haxe.Exception) {}
		}
		cookieBytes = null;
		cookiePath = null;
		if (runtimeCreated && runtimePath != null && Fs.existsSync(runtimePath)) {
			try {
				if (Fs.readdirSync(runtimePath).length == 0) {
					Fs.rmdirSync(runtimePath);
				}
			} catch (_:haxe.Exception) {}
		}
		runtimePath = null;
		runtimeCreated = false;
	}

	function clearServer():Void {
		child = null;
		port = null;
		compatibilityDigest = null;
		ready = false;
		stopping = false;
		childExited = false;
	}

	static function serverDigest(context:ProjectContext):String {
		return ProjectContract.string(ProjectContract.fieldObject(context.effectiveInputs, "compileServer", "effective inputs"), "compatibilityDigest",
			"compile server");
	}

	static function rootDigest(context:ProjectContext):String {
		return OwnershipJson.digest(Buffer.from(context.bootstrap.root, "utf8"));
	}

	static function processAlive(pid:Int):Bool {
		try {
			Syntax.code("process.kill({0}, 0)", pid);
			return true;
		} catch (_:haxe.Exception) {
			return false;
		}
	}
}
