export interface CalendarBadgeProps {
  readonly count: number;
  readonly label: string;
}

export declare function formatCalendarLabel(count: number): string;
export declare function CalendarBadge(props: CalendarBadgeProps): object;
