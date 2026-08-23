<?php

declare(strict_types=1);

namespace Acme\Calendar;

final class Event
{
    public function __construct(string $eventTitle) {}

    public function title(): string {}

    public function __call(string $name, array $arguments): mixed {}
}

/** @return list<Event> */
function list_events(int $limit): array {}

function conditional_helper(string $value): string {}

function mutate_all(Event &...$events): void {}
