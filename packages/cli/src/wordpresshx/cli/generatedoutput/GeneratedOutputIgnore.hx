package wordpresshx.cli.generatedoutput;

import wordpresshx.cli.CliFailure;
import wordpresshx.cli.scaffold.ScaffoldMarker;

/** Separate exact marker for narrow generated-root admission. */
class GeneratedOutputIgnore {
	public static inline final BEGIN = "# BEGIN wordpress-hx committed generated output";
	public static inline final END = "# END wordpress-hx committed generated output";

	public static function enable(source:String, roots:Array<GeneratedOutputRoot>):String {
		final normalized = ScaffoldMarker.replace(source);
		final bounds = markerBounds(normalized);
		if (bounds.present) {
			final expected = block(roots);
			final current = normalized.substr(bounds.start, bounds.end - bounds.start);
			if (current != expected) {
				fail("existing committed-output marker differs from the explicit root selection");
			}
			return normalized;
		}
		final managedEnd = normalized.indexOf(ScaffoldMarker.END + "\n");
		if (managedEnd < 0) {
			fail("managed ignore marker disappeared during normalization");
		}
		final insertion = managedEnd + ScaffoldMarker.END.length + 1;
		return normalized.substr(0, insertion) + block(roots) + normalized.substr(insertion);
	}

	public static function validate(source:String, roots:Array<GeneratedOutputRoot>):Void {
		if (ScaffoldMarker.replace(source) != source) {
			fail("managed ignore block differs from the current scaffold policy");
		}
		final bounds = markerBounds(source);
		if (!bounds.present || source.substr(bounds.start, bounds.end - bounds.start) != block(roots)) {
			fail("committed-output ignore marker is missing or differs from the policy");
		}
	}

	static function block(roots:Array<GeneratedOutputRoot>):String {
		final lines = [BEGIN];
		final parentSet = new Map<String, Bool>();
		for (root in roots) {
			final segments = root.path.split("/");
			var prefix = "";
			for (index in 0...(segments.length - 1)) {
				final segment = segments[index];
				prefix = prefix.length == 0 ? segment : prefix + "/" + segment;
				parentSet.set(prefix, true);
			}
		}
		final parents = [for (path => _ in parentSet) path];
		parents.sort(compareParent);
		for (parent in parents) {
			lines.push("!/" + parent + "/");
			lines.push("/" + parent + "/*");
		}
		final leaves = roots.copy();
		leaves.sort((left, right) -> compareText(left.path, right.path));
		for (root in leaves) {
			lines.push("!/" + root.path + "/");
			lines.push("!/" + root.path + "/**");
			lines.push("/" + root.path + "/.wphx-transactions/");
		}
		lines.push(END);
		return lines.join("\n") + "\n";
	}

	static function compareParent(left:String, right:String):Int {
		final leftDepth = left.split("/").length;
		final rightDepth = right.split("/").length;
		return leftDepth == rightDepth ? compareText(left, right) : leftDepth - rightDepth;
	}

	static function compareText(left:String, right:String):Int {
		return left < right ? -1 : left > right ? 1 : 0;
	}

	static function markerBounds(source:String):GeneratedOutputMarkerBounds {
		if (source.indexOf("\r") >= 0 || !StringTools.endsWith(source, "\n")) {
			fail(".gitignore must use LF lines and one final LF");
		}
		final beginToken = BEGIN + "\n";
		final endToken = END + "\n";
		final start = source.indexOf(beginToken);
		final secondStart = start < 0 ? -1 : source.indexOf(beginToken, start + beginToken.length);
		final endStart = source.indexOf(endToken);
		final secondEnd = endStart < 0 ? -1 : source.indexOf(endToken, endStart + endToken.length);
		if (start < 0 && endStart < 0) {
			return {present: false, start: 0, end: 0};
		}
		if (start < 0 || endStart < start || secondStart >= 0 || secondEnd >= 0) {
			fail(".gitignore must contain zero or one ordered committed-output marker pair");
		}
		return {present: true, start: start, end: endStart + endToken.length};
	}

	static function fail<T>(message:String):T {
		throw new CliFailure("WPHX3413", message, 5, "generated-output-policy", ".gitignore", [
			"Restore the exact WordPressHx markers; keep hand-owned ignore rules outside them."
		]);
	}
}

private typedef GeneratedOutputMarkerBounds = {
	final present:Bool;
	final start:Int;
	final end:Int;
}
