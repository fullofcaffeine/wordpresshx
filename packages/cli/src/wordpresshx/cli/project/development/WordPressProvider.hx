package wordpresshx.cli.project.development;

import haxe.DynamicAccess;
import haxe.Exception;
import haxe.Timer;
import js.lib.Error;
import js.node.ChildProcess;
import js.node.Crypto;
import js.node.Fs;
import js.node.Path;
import js.node.child_process.ChildProcess as NodeChildProcess;
import js.node.child_process.ChildProcess.ChildProcessEvent;
import wordpresshx.cli.CliFailure;
import wordpresshx.cli.NodeGlobals;
import wordpresshx.cli.closedjson.CanonicalJson;
import wordpresshx.cli.closedjson.JsonValue;
import wordpresshx.cli.closedjson.JsonValue.JsonField;
import wordpresshx.cli.project.development.DevelopmentPlan.DevelopmentService;

/** SDK-owned WordPress 7.0/MariaDB development process derived from Haxe intent. */
class WordPressProvider {
	static inline final WORDPRESS_IMAGE = "docker.io/library/wordpress@sha256:9a37e25aa7cb8b01a7a6c9ff0af7b9c0aca1ff78b489dd3756f90142a58d3161";
	static inline final DATABASE_IMAGE = "docker.io/library/mariadb@sha256:49117dcc565cf51aa57ac5fca59ab31213402ff0eae6ffc13c46a37b938f7e4b";
	static inline final INTERNAL_PASSWORD = "WPHX_INTERNAL_WORDPRESS_DB_PASSWORD";
	static inline final INTERNAL_ROOT_PASSWORD = "WPHX_INTERNAL_WORDPRESS_DB_ROOT_PASSWORD";
	static inline final CLEANUP_TIMEOUT_MS = 10000;
	static final EXECUTOR_ENVIRONMENT = [
		"DOCKER_CERT_PATH",
		"DOCKER_CONFIG",
		"DOCKER_CONTEXT",
		"DOCKER_HOST",
		"DOCKER_TLS_VERIFY",
		"HOME",
		"USERPROFILE"
	];

	public static function launch(project:DevelopmentProject, service:DevelopmentService, port:Int, workingDirectory:String,
			environment:DynamicAccess<String>):DevelopmentProcessLaunch {
		if (project.profileId != "wp70-release") {
			return invalid("the built-in WordPress provider has no exact image mapping for profile " + project.profileId);
		}
		for (name in service.environment) {
			if (reservedEnvironment(name)) {
				return invalid("runtime environment name " + name + " is reserved by the built-in WordPress provider");
			}
		}

		final configuredPassword = environment.get("WP_DB_PASSWORD");
		environment.remove("WP_DB_PASSWORD");
		environment.set(INTERNAL_PASSWORD, configuredPassword == null
			|| configuredPassword.length == 0 ? randomPassword() : configuredPassword);
		environment.set(INTERNAL_ROOT_PASSWORD, randomPassword());
		final hostEnvironment = NodeGlobals.process().env;
		for (name in EXECUTOR_ENVIRONMENT) {
			final value = hostEnvironment.get(name);
			if (value != null) {
				environment.set(name, value);
			}
		}
		final processIdentity = project.toolchainSha256.substr(0, 12) + "-" + Std.string(NodeGlobals.process().pid);
		final projectName = "wphx-" + processIdentity + "-" + safeName(service.id).substr(0, 24);
		final composePath = Path.join(project.root, ".wphx/runtime/" + projectName + ".compose.json");
		try {
			Fs.writeFileSync(composePath, CanonicalJson.encode(compose(project, service, port, environment)) + "\n", {
				encoding: "utf8",
				mode: 384,
				flag: "wx"
			});
		} catch (_:Exception) {
			return invalid("could not create its private generated Compose configuration");
		}

		final commonArguments = [
			"compose",
			"--ansi",
			"never",
			"--project-name",
			projectName,
			"--file",
			composePath
		];
		return {
			executable: "docker",
			arguments: commonArguments.concat(["up", "--abort-on-container-exit", "--force-recreate", "--remove-orphans"]),
			workingDirectory: workingDirectory,
			environment: environment,
			cleanup: done -> cleanup(commonArguments, workingDirectory, environment, composePath, done)
		};
	}

	static function compose(project:DevelopmentProject, service:DevelopmentService, port:Int, environment:DynamicAccess<String>):JsonValue {
		final wordpressEnvironment:Array<JsonField> = [
			field("WORDPRESS_DB_HOST", text("database:3306")),
			field("WORDPRESS_DB_NAME", text("wordpresshx")),
			field("WORDPRESS_DB_PASSWORD", interpolation(INTERNAL_PASSWORD)),
			field("WORDPRESS_DB_USER", text("wordpresshx")),
			field("WORDPRESS_DEBUG", text("1"))
		];
		for (name in service.environment) {
			if (environment.get(name) != null) {
				wordpressEnvironment.push(field(name, interpolation(name)));
			}
		}
		final labels = object([
			field("dev.wordpresshx.owned", text("true")),
			field("dev.wordpresshx.profile", text(project.profileId)),
			field("dev.wordpresshx.project", text(project.projectId)),
			field("dev.wordpresshx.service", text(service.id))
		]);
		return object([
			field("services", object([
				field("database", object([
					field("environment", object([
						field("MARIADB_DATABASE", text("wordpresshx")),
						field("MARIADB_PASSWORD", interpolation(INTERNAL_PASSWORD)),
						field("MARIADB_ROOT_PASSWORD", interpolation(INTERNAL_ROOT_PASSWORD)),
						field("MARIADB_USER", text("wordpresshx"))
					])),
					field("healthcheck", object([
						field("interval", text("1s")),
						field("retries", number(60)),
						field("start_period", text("2s")),
						field("test",
							array([
								text("CMD"),
								text("healthcheck.sh"),
								text("--connect"),
								text("--innodb_initialized")
							])),
						field("timeout", text("2s"))
					])),
					field("image", text(DATABASE_IMAGE)),
					field("labels", labels),
					field("stop_grace_period", text("3s"))
				])),
				field("wordpress", object([
					field("depends_on", object([field("database", object([field("condition", text("service_healthy"))]))])),
					field("environment", object(wordpressEnvironment)),
					field("image", text(WORDPRESS_IMAGE)),
					field("labels", labels),
					field("ports", array([text("127.0.0.1:" + Std.string(port) + ":80")])),
					field("stop_grace_period", text("3s"))
				]))
			]))
		]);
	}

	static function cleanup(commonArguments:Array<String>, workingDirectory:String, environment:DynamicAccess<String>, composePath:String,
			done:Void->Void):Void {
		var child:Null<NodeChildProcess> = null;
		var timer:Null<Timer> = null;
		var settled = false;
		final complete = () -> {
			if (settled) {
				return;
			}
			settled = true;
			if (timer != null) {
				timer.stop();
			}
			removeCompose(composePath);
			done();
		};
		try {
			child = ChildProcess.spawn("docker", commonArguments.concat(["down", "--remove-orphans", "--timeout", "3"]), {
				cwd: workingDirectory,
				env: environment,
				shell: false,
				stdio: ["ignore", "ignore", "ignore"]
			});
			child.once(ChildProcessEvent.Error, (_:Error) -> complete());
			child.once(ChildProcessEvent.Exit, (_:Int, _:String) -> complete());
			timer = Timer.delay(() -> {
				if (child != null) {
					child.kill("SIGKILL");
				}
				complete();
			}, CLEANUP_TIMEOUT_MS);
		} catch (_:Exception) {
			complete();
		}
	}

	static function removeCompose(path:String):Void {
		try {
			if (Fs.existsSync(path)) {
				Fs.unlinkSync(path);
			}
		} catch (_:Exception) {}
	}

	static function randomPassword():String {
		return Crypto.randomBytes(32).toString("hex");
	}

	static function interpolation(name:String):JsonValue {
		return text("${" + name + ":?required}");
	}

	static function reservedEnvironment(name:String):Bool {
		return name == INTERNAL_PASSWORD
			|| name == INTERNAL_ROOT_PASSWORD
			|| StringTools.startsWith(name, "WORDPRESS_")
			|| StringTools.startsWith(name, "MARIADB_")
			|| StringTools.startsWith(name, "DOCKER_")
			|| StringTools.startsWith(name, "COMPOSE_");
	}

	static function safeName(value:String):String {
		final result = new StringBuf();
		for (index in 0...value.length) {
			final character = value.charAt(index);
			result.add(~/[a-z0-9]/.match(character) ? character : "-");
		}
		return result.toString();
	}

	static function object(fields:Array<JsonField>):JsonValue {
		return ObjectValue(fields);
	}

	static function array(values:Array<JsonValue>):JsonValue {
		return ArrayValue(values);
	}

	static function text(value:String):JsonValue {
		return StringValue(value);
	}

	static function number(value:Int):JsonValue {
		return NumberValue(Std.string(value));
	}

	static function field(name:String, value:JsonValue):JsonField {
		return {name: name, value: value};
	}

	static function invalid<T>(message:String):T {
		throw new CliFailure("WPHX2330", "SDK-owned WordPress development provider " + message, 7, "service-start", null, [
			"Use the exact wp70-release provider with a working Docker Compose v2 installation, or run with --services=none."
		]);
	}
}
