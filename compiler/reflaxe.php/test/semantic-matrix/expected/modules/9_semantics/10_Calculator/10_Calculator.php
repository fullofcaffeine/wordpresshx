<?php

declare(strict_types=1);

class Hx_9_semantics_10_Calculator {
	public static function add(int $left, int $right): int {
		return $left + $right;
	}

	public static function decorate(string $prefix, string $value): string {
		return $prefix . $value;
	}
}
