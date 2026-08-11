<?php

declare(strict_types=1);

class Hx_9_semantics_10_Calculator {
	public static function add(int $left, int $right): int {
		return \ReflaxePhpInt32Runtime::add( $left, $right );
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

	public static function multiply(int $left, int $right): int {
		return \ReflaxePhpInt32Runtime::multiply( $left, $right );
	}

	public static function negate(bool $value): bool {
		return ! $value;
	}

	public static function negateInt(int $value): int {
		return \ReflaxePhpInt32Runtime::negate( $value );
	}

	public static function probe(bool $value): bool {
		echo 'bool-probe' . PHP_EOL;
		return $value;
	}

	public static function remainderByFive(int $value): int {
		return $value % 5;
	}

	public static function roundTrip(?string $value): ?string {
		return $value;
	}

	public static function subtract(int $left, int $right): int {
		return \ReflaxePhpInt32Runtime::subtract( $left, $right );
	}
}
