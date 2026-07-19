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
	static inline final INTERNAL_RELOAD_CLIENT = "WPHX_INTERNAL_WORDPRESS_RELOAD_CLIENT";
	static inline final INTERNAL_RELOAD_EVENTS = "WPHX_INTERNAL_WORDPRESS_RELOAD_EVENTS";
	static inline final INTERNAL_ADMIN_PASSWORD = "WPHX_INTERNAL_WORDPRESS_ADMIN_PASSWORD";
	static inline final INTERNAL_PLUGIN_ENTRY = "WPHX_INTERNAL_WORDPRESS_PLUGIN_ENTRY";
	static inline final INTERNAL_SITE_TITLE = "WPHX_INTERNAL_WORDPRESS_SITE_TITLE";
	static inline final INTERNAL_SITE_URL = "WPHX_INTERNAL_WORDPRESS_SITE_URL";
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
			environment:DynamicAccess<String>, reload:Null<WordPressReloadAdapter>):DevelopmentProcessLaunch {
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
		if (reload == null) {
			return invalid("requires its derived browser reload adapter");
		}
		environment.set(INTERNAL_RELOAD_CLIENT, reload.clientUrl);
		environment.set(INTERNAL_RELOAD_EVENTS, reload.eventsUrl);
		final deployablePlugin = project.deployablePlugin;
		if (deployablePlugin != null) {
			environment.set(INTERNAL_ADMIN_PASSWORD, randomPassword());
			environment.set(INTERNAL_PLUGIN_ENTRY, deployablePlugin.entry);
			environment.set(INTERNAL_SITE_TITLE, project.projectId);
			environment.set(INTERNAL_SITE_URL, "http://127.0.0.1:" + Std.string(port));
		}
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
		final pluginDirectory = Path.join(project.root, ".wphx/runtime/" + projectName + ".mu-plugins");
		final pluginPath = Path.join(pluginDirectory, "wordpresshx-dev-reload.php");
		final bootstrapPath = Path.join(pluginDirectory, "wordpresshx-dev-bootstrap.php");
		try {
			Fs.mkdirSync(pluginDirectory, 448);
			Fs.writeFileSync(pluginPath, WordPressReloadAdapter.pluginSource(), {
				encoding: "utf8",
				mode: 384,
				flag: "wx"
			});
			if (deployablePlugin != null) {
				Fs.writeFileSync(bootstrapPath, WordPressBootstrapAdapter.source(), {
					encoding: "utf8",
					mode: 384,
					flag: "wx"
				});
			}
			Fs.writeFileSync(composePath, CanonicalJson.encode(compose(project, service, port, environment, pluginPath, bootstrapPath)) + "\n", {
				encoding: "utf8",
				mode: 384,
				flag: "wx"
			});
		} catch (_:Exception) {
			removeRuntimeFiles(composePath, pluginPath, bootstrapPath, pluginDirectory);
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
			cleanup: done -> cleanup(commonArguments, workingDirectory, environment, composePath, pluginPath, bootstrapPath, pluginDirectory, done)
		};
	}

	static function compose(project:DevelopmentProject, service:DevelopmentService, port:Int, environment:DynamicAccess<String>, pluginPath:String,
			bootstrapPath:String):JsonValue {
		if (project.deployablePlugin != null) {
			return pluginCompose(project, service, port, pluginPath, bootstrapPath);
		}
		final wordpressEnvironment:Array<JsonField> = [
			field("WORDPRESS_DB_HOST", text("database:3306")),
			field("WORDPRESS_DB_NAME", text("wordpresshx")),
			field("WORDPRESS_DB_PASSWORD", interpolation(INTERNAL_PASSWORD)),
			field("WORDPRESS_DB_USER", text("wordpresshx")),
			field("WORDPRESS_DEBUG", text("1")),
			field("WPHX_DEV_RELOAD_CLIENT", interpolation(INTERNAL_RELOAD_CLIENT)),
			field("WPHX_DEV_RELOAD_EVENTS", interpolation(INTERNAL_RELOAD_EVENTS))
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
					field("stop_grace_period", text("3s")),
					field("volumes", array([
						object([
							field("read_only", BoolValue(true)),
							field("source", text(pluginPath)),
							field("target", text("/var/www/html/wp-content/mu-plugins/wordpresshx-dev-reload.php")),
							field("type", text("bind"))
						])
					]))
				]))
			]))
		]);
	}

	static function pluginCompose(project:DevelopmentProject, service:DevelopmentService, port:Int, reloadPath:String, bootstrapPath:String):JsonValue {
		final plugin = project.deployablePlugin;
		if (plugin == null) {
			return invalid("lost its compiler-derived plugin before composing the development provider");
		}
		final labels = object([
			field("dev.wordpresshx.owned", text("true")),
			field("dev.wordpresshx.profile", text(project.profileId)),
			field("dev.wordpresshx.project", text(project.projectId)),
			field("dev.wordpresshx.service", text(service.id))
		]);
		final databaseEnvironment = object([
			field("MARIADB_DATABASE", text("wordpresshx")),
			field("MARIADB_PASSWORD", interpolation(INTERNAL_PASSWORD)),
			field("MARIADB_ROOT_PASSWORD", interpolation(INTERNAL_ROOT_PASSWORD)),
			field("MARIADB_USER", text("wordpresshx"))
		]);
		final wordpressEnvironment = object([
			field("WORDPRESS_DB_HOST", text("database:3306")),
			field("WORDPRESS_DB_NAME", text("wordpresshx")),
			field("WORDPRESS_DB_PASSWORD", interpolation(INTERNAL_PASSWORD)),
			field("WORDPRESS_DB_USER", text("wordpresshx")),
			field("WORDPRESS_DEBUG", text("1")),
			field("WPHX_DEV_PLUGIN_ENTRY", interpolation(INTERNAL_PLUGIN_ENTRY)),
			field("WPHX_DEV_RELOAD_CLIENT", interpolation(INTERNAL_RELOAD_CLIENT)),
			field("WPHX_DEV_RELOAD_EVENTS", interpolation(INTERNAL_RELOAD_EVENTS))
		]);
		final bootstrapEnvironment = object([
			field("WORDPRESS_DB_HOST", text("database:3306")),
			field("WORDPRESS_DB_NAME", text("wordpresshx")),
			field("WORDPRESS_DB_PASSWORD", interpolation(INTERNAL_PASSWORD)),
			field("WORDPRESS_DB_USER", text("wordpresshx")),
			field("WPHX_INTERNAL_WORDPRESS_ADMIN_PASSWORD", interpolation(INTERNAL_ADMIN_PASSWORD)),
			field("WPHX_INTERNAL_WORDPRESS_PLUGIN_ENTRY", interpolation(INTERNAL_PLUGIN_ENTRY)),
			field("WPHX_INTERNAL_WORDPRESS_SITE_TITLE", interpolation(INTERNAL_SITE_TITLE)),
			field("WPHX_INTERNAL_WORDPRESS_SITE_URL", interpolation(INTERNAL_SITE_URL))
		]);
		final wordpressData = object([
			field("source", text("wordpress-data")),
			field("target", text("/var/www/html")),
			field("type", text("volume"))
		]);
		final reloadVolume = object([
			field("read_only", BoolValue(true)),
			field("source", text(reloadPath)),
			field("target", text("/var/www/html/wp-content/mu-plugins/wordpresshx-dev-reload.php")),
			field("type", text("bind"))
		]);
		final pluginVolume = object([
			field("read_only", BoolValue(true)),
			field("source", text(Path.resolve(project.root, plugin.relativeDirectory))),
			field("target", text("/var/www/html/wp-content/plugins/" + plugin.slug)),
			field("type", text("bind"))
		]);
		final bootstrapVolume = object([
			field("read_only", BoolValue(true)),
			field("source", text(bootstrapPath)),
			field("target", text("/opt/wordpresshx/dev-bootstrap.php")),
			field("type", text("bind"))
		]);
		final wordpressHealthcheck = object([
			field("interval", text("1s")),
			field("retries", number(120)),
			field("start_period", text("1s")),
			field("test", array([
				text("CMD"),
				text("php"),
				text("-r"),
				text("exit(is_file('/var/www/html/wp-load.php') && is_file('/var/www/html/wp-config.php') "
					+ "&& is_file('/var/www/html/wp-settings.php') && is_file('/var/www/html/wp-includes/version.php') "
					+ "&& is_file('/var/www/html/wp-admin/includes/upgrade.php') "
					+ "&& is_file('/var/www/html/wp-admin/includes/plugin.php') "
					+ "&& is_file('/var/www/html/wp-content/plugins/"
					+ plugin.entry
					+ "') ? 0 : 1);")
			])),
			field("timeout", text("2s"))
		]);
		return object([
			field("networks", object([field("default", object([field("labels", labels)]))])),
			field("services", object([
				field("bootstrap", object([
					field("command", array([text("/opt/wordpresshx/dev-bootstrap.php")])),
					field("depends_on",
						object([
							field("database", object([field("condition", text("service_healthy"))])),
							field("wordpress", object([field("condition", text("service_healthy"))]))
						])),
					field("entrypoint", array([text("php")])),
					field("environment", bootstrapEnvironment),
					field("image", text(WORDPRESS_IMAGE)),
					field("labels", labels),
					field("stop_grace_period", text("1s")),
					field("volumes", array([wordpressData, pluginVolume, bootstrapVolume]))
				])),
				field("database", object([
					field("environment", databaseEnvironment),
					field("healthcheck", object([
						field("interval", text("1s")),
						field("retries", number(120)),
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
					field("environment", wordpressEnvironment),
					field("healthcheck", wordpressHealthcheck),
					field("image", text(WORDPRESS_IMAGE)),
					field("labels", labels),
					field("ports", array([text("127.0.0.1:" + Std.string(port) + ":80")])),
					field("stop_grace_period", text("3s")),
					field("volumes", array([reloadVolume, wordpressData, pluginVolume]))
				]))
			])),
			field("volumes", object([field("wordpress-data", object([field("labels", labels)]))]))
		]);
	}

	static function cleanup(commonArguments:Array<String>, workingDirectory:String, environment:DynamicAccess<String>, composePath:String, pluginPath:String,
			bootstrapPath:String, pluginDirectory:String, done:Void->Void):Void {
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
			removeRuntimeFiles(composePath, pluginPath, bootstrapPath, pluginDirectory);
			done();
		};
		try {
			child = ChildProcess.spawn("docker", commonArguments.concat(["down", "--remove-orphans", "--timeout", "3", "--volumes"]), {
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

	static function removeRuntimeFiles(composePath:String, pluginPath:String, bootstrapPath:String, pluginDirectory:String):Void {
		try {
			if (Fs.existsSync(composePath)) {
				Fs.unlinkSync(composePath);
			}
		} catch (_:Exception) {}
		try {
			if (Fs.existsSync(bootstrapPath)) {
				Fs.unlinkSync(bootstrapPath);
			}
		} catch (_:Exception) {}
		try {
			if (Fs.existsSync(pluginPath)) {
				Fs.unlinkSync(pluginPath);
			}
		} catch (_:Exception) {}
		try {
			if (Fs.existsSync(pluginDirectory)) {
				Fs.rmdirSync(pluginDirectory);
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
			|| name == INTERNAL_RELOAD_CLIENT
			|| name == INTERNAL_RELOAD_EVENTS
			|| name == INTERNAL_ADMIN_PASSWORD
			|| name == INTERNAL_PLUGIN_ENTRY
			|| name == INTERNAL_SITE_TITLE
			|| name == INTERNAL_SITE_URL
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
