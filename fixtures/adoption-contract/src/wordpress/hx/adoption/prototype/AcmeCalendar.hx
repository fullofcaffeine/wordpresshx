package wordpress.hx.adoption.prototype;

import wordpress.hx.adoption.prototype.Adoption.CapabilityContract;
import wordpress.hx.adoption.prototype.Adoption.CapabilityToken;
import wordpress.hx.adoption.prototype.Adoption.ProviderContract;
import wordpress.hx.adoption.prototype.Adoption.RequestScope;

final class AcmeCalendarProvider {}
final class CalendarReadCapability {}
final class CalendarBadgeCapability {}

final class AcmeCalendar {
	public static final provider = new ProviderContract<AcmeCalendarProvider>("acme-calendar", "2.4.1",
		"6bc3d2b6beb3b5a2b9913caf229172b89c666d295a62f2f55f245952e7d74013");

	public static final read = new CapabilityContract<AcmeCalendarProvider, CalendarReadCapability>("calendar.read.php", ["php.calendar.list-events"]);

	public static final badge = new CapabilityContract<AcmeCalendarProvider, CalendarBadgeCapability>("calendar.badge.browser",
		["js.calendar.badge", "js.calendar.format-label"]);
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
	public static function listEvents<Scope>(scope:RequestScope<Scope>, token:CapabilityToken<AcmeCalendarProvider, CalendarReadCapability, Scope>,
			query:EventQuery):String {
		if (!token.authorizes(scope, AcmeCalendar.provider, AcmeCalendar.read)) {
			throw new haxe.Exception("request-scoped provider token is stale or mismatched");
		}
		return "php-call|Acme\\Calendar\\list_events|limit=" + query.limit;
	}

	public static function renderBadge<Scope>(scope:RequestScope<Scope>, token:CapabilityToken<AcmeCalendarProvider, CalendarBadgeCapability, Scope>,
			props:CalendarBadgeProps):String {
		if (!token.authorizes(scope, AcmeCalendar.provider, AcmeCalendar.badge)) {
			throw new haxe.Exception("browser-module provider token is stale or mismatched");
		}
		return "js-call|@acme/calendar.CalendarBadge|count=" + props.count + "|label=" + props.label;
	}
}
