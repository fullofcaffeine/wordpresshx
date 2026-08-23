package wordpress.hx.adoption.prototype;

import wordpress.hx.adoption.prototype.Adoption.BrowserModuleScope;
import wordpress.hx.adoption.prototype.Adoption.CapabilityContract;
import wordpress.hx.adoption.prototype.Adoption.CapabilityRequirement;
import wordpress.hx.adoption.prototype.Adoption.CapabilityToken;
import wordpress.hx.adoption.prototype.Adoption.LifecycleKind;
import wordpress.hx.adoption.prototype.Adoption.PhpRequestScope;
import wordpress.hx.adoption.prototype.Adoption.ProviderContract;

final class AcmeCalendarProvider {}
final class CalendarReadCapability {}
final class CalendarBadgeCapability {}

final class AcmeCalendar {
	public static final provider = new ProviderContract<AcmeCalendarProvider>("acme-calendar", "2.4.1",
		"923412beee77cce43964a12358bb099ac07014bd37973df9910de3ad15b9cabd", "db9fbcddfcb798767c8078cbae8ea27d9fe989a5c62f089c51cfc99f55fadfb9");

	public static final read = new CapabilityContract<AcmeCalendarProvider, CalendarReadCapability, PhpRequestScope>("calendar.read.php",
		LifecycleKind.PhpRequest, CapabilityRequirement.Required, [
			"php.calendar.event.construct",
			"php.calendar.event.title",
			"php.calendar.list-events"
		]);

	public static final badge = new CapabilityContract<AcmeCalendarProvider, CalendarBadgeCapability, BrowserModuleScope>("calendar.badge.browser",
		LifecycleKind.BrowserModule, CapabilityRequirement.Optional, ["js.calendar.badge", "js.calendar.format-label"]);
}

final class EventQuery {
	public final limit:Int;

	public function new(limit:Int) {
		this.limit = limit;
	}
}

final class CalendarBadgeProps {
	public final count:Int;
	public final label:String;

	public function new(count:Int, label:String) {
		this.count = count;
		this.label = label;
	}
}

final class AcmeCalendarFacade {
	public static function listEvents(scope:PhpRequestScope, token:CapabilityToken<AcmeCalendarProvider, CalendarReadCapability, PhpRequestScope>,
			query:EventQuery):String {
		if (!token.authorizes(scope, AcmeCalendar.provider, AcmeCalendar.read)) {
			throw new haxe.Exception("PHP request provider token is stale or mismatched");
		}
		return "php-call|Acme\\Calendar\\list_events|limit=" + query.limit;
	}

	public static function renderBadge(scope:BrowserModuleScope, token:CapabilityToken<AcmeCalendarProvider, CalendarBadgeCapability, BrowserModuleScope>,
			props:CalendarBadgeProps):String {
		if (!token.authorizes(scope, AcmeCalendar.provider, AcmeCalendar.badge)) {
			throw new haxe.Exception("browser-module provider token is stale or mismatched");
		}
		return "js-call|@acme/calendar.CalendarBadge|count=" + props.count + "|label=" + props.label;
	}
}
