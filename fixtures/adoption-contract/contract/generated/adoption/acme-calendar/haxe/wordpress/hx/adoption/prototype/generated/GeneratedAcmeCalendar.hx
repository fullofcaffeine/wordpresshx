package wordpress.hx.adoption.prototype.generated;

import wordpress.hx.adoption.prototype.Adoption.BrowserModuleScope;
import wordpress.hx.adoption.prototype.Adoption.CapabilityContract;
import wordpress.hx.adoption.prototype.Adoption.CapabilityRequirement;
import wordpress.hx.adoption.prototype.Adoption.LifecycleKind;
import wordpress.hx.adoption.prototype.Adoption.PhpRequestScope;
import wordpress.hx.adoption.prototype.Adoption.ProviderContract;

final class AcmeCalendarProvider {}
final class CalendarReadCapability {}
final class CalendarBadgeCapability {}

final class GeneratedAcmeCalendar {
	public static final provider = new ProviderContract<AcmeCalendarProvider>("acme-calendar", "2.4.1",
		"923412beee77cce43964a12358bb099ac07014bd37973df9910de3ad15b9cabd");

	public static final read = new CapabilityContract<AcmeCalendarProvider, CalendarReadCapability, PhpRequestScope>("calendar.read.php",
		LifecycleKind.PhpRequest, CapabilityRequirement.Required, [
			"php.calendar.event.construct",
			"php.calendar.event.title",
			"php.calendar.list-events"
		], "8d87130bc484658004329fcdf7b603d82f697b49169d119c05758e0ac014d203");

	public static final badge = new CapabilityContract<AcmeCalendarProvider, CalendarBadgeCapability, BrowserModuleScope>("calendar.badge.browser",
		LifecycleKind.BrowserModule, CapabilityRequirement.Optional, ["js.calendar.badge", "js.calendar.format-label"],
		"f072306f4ce994dd45ab045a122bcf77cd76a15d78a5941cc7d2815d24e9e46e");
}

final class EventQuery {
	public final limit:Int;

	public function new(limit:Int) {
		this.limit = limit;
	}
}

final class CalendarBadgeProps {
	public final count:Float;
	public final label:String;

	public function new(count:Float, label:String) {
		this.count = count;
		this.label = label;
	}
}

#if php
@:native("WordPressHxAcmeCalendarVerifiedProvider")
extern class GeneratedPhpProviderHandle {
	public final bundleDigest:String;
	public final executableClosureSha256:String;
}

@:native("WordPressHxAcmeCalendarFacade")
extern class GeneratedPhpFacade {
	public static function open(pluginFile:String, bundleFile:String):GeneratedPhpProviderHandle;

	public static function listEventTitles(provider:GeneratedPhpProviderHandle, limit:Int):php.NativeIndexedArray<String>;
}
#end

#if js
/** Opaque because the authoritative TypeScript declaration promises only object. */
extern class GeneratedJavascriptObject {}

extern class GeneratedBrowserProviderHandle {
	public final bundleDigest:String;
	public final executableClosureSha256:String;
	public function formatLabel(count:Float):String;
	public function renderBadge(props:CalendarBadgeProps):GeneratedJavascriptObject;
}

@:native("WordPressHxAcmeCalendarFacade")
extern class GeneratedBrowserFacade {
	public static function openExactProvider(packageRoot:String, generation:String, bundleFile:String):js.lib.Promise<GeneratedBrowserProviderHandle>;
}
#end
