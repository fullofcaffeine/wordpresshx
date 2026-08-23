import { appendFileSync } from "node:fs";

const sentinel = process.env.WORDPRESSHX_ADOPTION_POISON_SENTINEL;
if (sentinel) {
  appendFileSync(sentinel, "browser provider code executed\n", "utf8");
}

export function formatCalendarLabel(count) {
  if (count < 0) {
    throw new RangeError("count must be non-negative");
  }
  return `${count} calendar events`;
}

export function CalendarBadge(props) {
  return Object.freeze({
    kind: "acme-calendar-badge",
    count: props.count,
    label: props.label,
  });
}

export const CalendarRegistry = Object.freeze({
  primary: CalendarBadge,
});
