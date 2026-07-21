package sdk041.fixture;

import js.Syntax;
import wordpresshx.cli.NodeGlobals;
import wordpresshx.cli.ownership.ArtifactOwner;
import wordpresshx.cli.ownership.OwnershipFailure;
import wordpresshx.cli.ownership.OwnershipJson;
import wordpresshx.cli.ownership.StageValidator;

/** Subprocess entry used to prove the production Haxe ownership transaction. **/
class Main {
	static function main():Void {
		final nodeProcess = NodeGlobals.process();
		try {
			final arguments = nodeProcess.argv.slice(2);
			if (arguments.length < 2) {
				throw new OwnershipFailure("usage: ownership-fixture <command> <project> [arguments]", "usage");
			}
			final command = arguments[0];
			final owner = new ArtifactOwner(arguments[1], null, checkpoint);
			final outcome:String = switch (command) {
				case "publish":
					if (arguments.length != 4 && arguments.length != 5) {
						throw new OwnershipFailure("publish requires <manifest> <stage> [pass|fail]", "usage");
					}
					final validatorMode = arguments.length == 5 ? arguments[4] : "pass";
					final validators:Array<StageValidator> = [
						{
							validatorId: "fixture.bytes",
							run: _ -> {
								if (validatorMode == "fail") {
									throw new OwnershipFailure("fixture validator failed", "fixture-validator");
								}
							}
						}
					];
					owner.publish(arguments[2], arguments[3], validators);
				case "clean":
					if (arguments.length != 2) {
						throw new OwnershipFailure("clean takes no additional arguments", "usage");
					}
					owner.clean();
				case "adopt":
					if (arguments.length < 3) {
						throw new OwnershipFailure("adopt requires exact paths", "usage");
					}
					owner.adoptGenerated(arguments.slice(2));
				case "recover":
					if (arguments.length != 2) {
						throw new OwnershipFailure("recover takes no additional arguments", "usage");
					}
					owner.recover();
				case "inspect":
					if (arguments.length != 2) {
						throw new OwnershipFailure("inspect takes no additional arguments", "usage");
					}
					final manifest = owner.inspectCurrentManifest();
					nodeProcess.stdout.write(OwnershipJson.encode(OwnershipJson.object(["manifest" => manifest])) + "\n");
					return;
				case _:
					throw new OwnershipFailure("unknown ownership fixture command", "usage");
			}
			nodeProcess.stdout.write(OwnershipJson.encode(OwnershipJson.object(["outcome" => outcome])) + "\n");
		} catch (failure:OwnershipFailure) {
			final report = OwnershipJson.object([
				"code" => failure.code,
				"message" => failure.message,
				"path" => failure.relativePath
			]);
			nodeProcess.stderr.write(OwnershipJson.encode(report) + "\n");
			nodeProcess.exit(failure.code == "usage" ? 2 : 3);
		} catch (_:haxe.Exception) {
			nodeProcess.stderr.write('{"code":"unexpected","message":"unexpected ownership fixture failure","path":null}\n');
			nodeProcess.exit(4);
		}
	}

	static function checkpoint(name:String):Void {
		final configured:Null<String> = Syntax.code("process.env.WPHX_OWNERSHIP_FAULT");
		if (configured == null) {
			return;
		}
		final value:String = configured;
		final separator = value.indexOf(":");
		if (separator <= 0 || value.substr(separator + 1) != name) {
			return;
		}
		if (value.substr(0, separator) == "crash") {
			NodeGlobals.process().exit(91);
		}
		if (value.substr(0, separator) == "caught") {
			throw new OwnershipFailure("injected caught failure at " + name, "injected-failure");
		}
	}
}
