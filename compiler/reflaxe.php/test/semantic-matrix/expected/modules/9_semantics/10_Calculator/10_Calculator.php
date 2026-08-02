<?php

declare(strict_types=1);

class Hx_9_semantics_10_Calculator {
	public static function add(int $left, int $right): int {
		return $left + $right;
	}

	public static function decorate(string $prefix, string $value): string {
		return $prefix . $value;
	}

	public static function isMissing(?string $value): bool {
		return $value === null;
	}

	public static function isPresent(?string $value): bool {
		return $value !== null;
	}

	public static function negate(bool $value): bool {
		return ! $value;
	}

	public static function probe(bool $value): bool {
		echo 'bool-probe' . PHP_EOL;
		return $value;
	}
}
