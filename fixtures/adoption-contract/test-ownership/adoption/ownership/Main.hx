package adoption.ownership;

import wordpresshx.cli.NodeGlobals;
import wordpresshx.cli.ownership.ArtifactOwner;
import wordpresshx.cli.ownership.OwnershipFailure;
import wordpresshx.cli.ownership.OwnershipJson;
import wordpresshx.cli.ownership.StageValidator;

/** ADR-015 subprocess entry that drives the production ownership transaction. */
final class Main {
	static function main():Void {
		final nodeProcess = NodeGlobals.process();
		try {
			final arguments = nodeProcess.argv.slice(2);
			if (arguments.length < 2) {
				throw new OwnershipFailure("usage: adoption-owner <command> <project> [arguments]", "usage");
			}
			final owner = new ArtifactOwner(arguments[1], {
				manifestPath: "generated/_GeneratedFiles.json",
				transactionRoot: "generated/.wphx-transactions"
			}, checkpoint);
			final outcome:String = switch (arguments[0]) {
				case "publish-adoption":
					if (arguments.length != 4 && arguments.length != 5) {
						throw new OwnershipFailure("publish requires <manifest> <stage> [pass|fail]", "usage");
					}
					final validatorMode = arguments.length == 5 ? arguments[4] : "pass";
					final validators:Array<StageValidator> = [
						{
							validatorId: "adoption.bundle",
							run: stageRoot -> {
								if (validatorMode == "fail") {
									throw new OwnershipFailure("fixture validator failed", "fixture-validator");
								}
								AdoptionBundleValidator.validate(stageRoot);
							}
						}
					];
					owner.publish(arguments[2], arguments[3], validators);
				case "clean-adoption":
					if (arguments.length != 2) {
						throw new OwnershipFailure("clean takes no additional arguments", "usage");
					}
					owner.clean();
				case "recover-adoption":
					if (arguments.length != 2) {
						throw new OwnershipFailure("recover takes no additional arguments", "usage");
					}
					owner.recover();
				case _:
					throw new OwnershipFailure("unknown adoption ownership command", "usage");
			}
			nodeProcess.stdout.write(OwnershipJson.encode(OwnershipJson.object(["outcome" => OwnershipJson.text(outcome)])) + "\n");
		} catch (failure:OwnershipFailure) {
			final report = OwnershipJson.object([
				"code" => OwnershipJson.text(failure.code),
				"message" => OwnershipJson.text(failure.message),
				"path" => OwnershipJson.nullableText(failure.relativePath)
			]);
			nodeProcess.stderr.write(OwnershipJson.encode(report) + "\n");
			nodeProcess.exit(failure.code == "usage" ? 2 : 3);
		} catch (_:haxe.Exception) {
			nodeProcess.stderr.write('{"code":"unexpected","message":"unexpected adoption ownership failure","path":null}\n');
			nodeProcess.exit(4);
		}
	}

	static function checkpoint(name:String):Void {
		final configured = NodeGlobals.process().env.get("WPHX_OWNERSHIP_FAULT");
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
