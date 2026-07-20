<?php

declare(strict_types=1);

namespace Acme\Calendar;

final class Event
{
    public function title(): string {}
}

/** @return list<Event> */
function list_events(int $limit): array {}
