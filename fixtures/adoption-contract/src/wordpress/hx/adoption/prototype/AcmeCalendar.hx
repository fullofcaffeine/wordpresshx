package wordpress.hx.adoption.prototype;

import wordpress.hx.adoption.prototype.generated.GeneratedAcmeCalendar;

typedef AcmeCalendarProvider = wordpress.hx.adoption.prototype.generated.GeneratedAcmeCalendar.AcmeCalendarProvider;
typedef CalendarReadCapability = wordpress.hx.adoption.prototype.generated.GeneratedAcmeCalendar.CalendarReadCapability;
typedef CalendarBadgeCapability = wordpress.hx.adoption.prototype.generated.GeneratedAcmeCalendar.CalendarBadgeCapability;
typedef EventQuery = wordpress.hx.adoption.prototype.generated.GeneratedAcmeCalendar.EventQuery;
typedef CalendarBadgeProps = wordpress.hx.adoption.prototype.generated.GeneratedAcmeCalendar.CalendarBadgeProps;

/** Stable authored entry point whose provider-specific ABI is generated from source bytes. */
final class AcmeCalendar {
	public static final provider = GeneratedAcmeCalendar.provider;
	public static final read = GeneratedAcmeCalendar.read;
	public static final badge = GeneratedAcmeCalendar.badge;
}
