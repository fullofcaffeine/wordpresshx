<?php
declare(strict_types=1);

namespace Fixture;

function fail(): void {
	throw new \RuntimeException('ADR-014');
}
