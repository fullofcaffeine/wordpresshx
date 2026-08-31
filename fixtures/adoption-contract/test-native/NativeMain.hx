#if js
import js.Node;
import wordpress.hx.adoption.prototype.Adoption.BrowserAcmeCalendarAdapter;
import wordpress.hx.adoption.prototype.generated.GeneratedAcmeCalendar.CalendarBadgeProps;
import wordpress.hx.adoption.prototype.generated.GeneratedAcmeCalendar.GeneratedJavascriptObject;
#elseif php
import wordpress.hx.adoption.prototype.Adoption.PhpAcmeCalendarAdapter;
import wordpress.hx.adoption.prototype.generated.GeneratedAcmeCalendar.EventQuery;
#end

final class NativeMain {
	static function main():Void {
		final providerPath = requiredEnvironment("WORDPRESSHX_ADOPTION_PROVIDER_PATH");
		final bundleFile = requiredEnvironment("WORDPRESSHX_ADOPTION_BUNDLE_PATH");
		#if js
		final generation = requiredEnvironment("WORDPRESSHX_ADOPTION_GENERATION");
		BrowserAcmeCalendarAdapter.open(providerPath, generation, bundleFile).then(adapter -> {
			final label = adapter.formatLabel(3.5);
			if (label != "3.5 calendar events") {
				throw new haxe.Exception("Haxe observer received a non-immediate or wrong JavaScript label");
			}
			final badge = adapter.renderBadge(new CalendarBadgeProps(3.5, label));
			if (!BadgeCarrierObserver.observe(badge)) {
				throw new haxe.Exception("Haxe observer received a mutable or thenable JavaScript carrier");
			}
			Node.process.stdout.write("haxe-js-native|immediate-string|opaque-object-observed\n");
			return adapter;
		});
		#elseif php
		final adapter = PhpAcmeCalendarAdapter.open(providerPath, bundleFile);
		final titles = adapter.listEventTitles(new EventQuery(2));
		Sys.println("haxe-php-native|" + titles.join("|"));
		#else
		throw new haxe.Exception("native provider observer requires PHP or JavaScript");
		#end
	}

	static function requiredEnvironment(name:String):String {
		final value = Sys.getEnv(name);
		if (value == null || value == "") {
			throw new haxe.Exception("missing native observer environment: " + name);
		}
		return value;
	}
}

#if js
@:native("WordPressHxBadgeCarrierObserver")
extern class BadgeCarrierObserver {
	public static function observe(value:GeneratedJavascriptObject):Bool;
}
#end
