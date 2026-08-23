<?php

declare(strict_types=1);

namespace Acme\Calendar;

/*
Plugin Name: Acme Calendar
Version: 2.4.1
*/

$sentinel = getenv('WORDPRESSHX_ADOPTION_POISON_SENTINEL');
if (is_string($sentinel) && $sentinel !== '') {
    file_put_contents($sentinel, 'provider code executed');
}

final class Event
{
    public function __construct(private string $eventTitle) {}

    public function title(): string
    {
        return $this->eventTitle;
    }

    public function __call(string $name, array $arguments): mixed
    {
        throw new \BadMethodCallException($name);
    }
}

/** @return list<Event> */
function list_events(int $limit): array
{
    if ($limit < 0) {
        throw new \InvalidArgumentException('limit must be non-negative');
    }

    return array_slice(
        [new Event('Provider event one'), new Event('Provider event two')],
        0,
        $limit
    );
}

function conditional_helper(int $value): string
{
    return (string) $value;
}

function mutate_all(Event &...$events): void
{
    $events = array_reverse($events);
}
