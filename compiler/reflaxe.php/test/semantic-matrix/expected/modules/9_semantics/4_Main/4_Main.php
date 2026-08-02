<?php

declare(strict_types=1);

class Hx_9_semantics_4_Main {
	public static function main(): void {
		$answer = Hx_9_semantics_10_Calculator::add( 40, 2 );
		if ( $answer === 42 ) {
			echo 'numeric-control-flow:pass' . PHP_EOL;
		} else {
			echo 'numeric-control-flow:fail' . PHP_EOL;
		}
		$total = 0;
		$current = 1;
		while ( $current <= 4 ) {
			$total = $total + $current;
			$current = $current + 1;
		}
		if ( $total === 10 ) {
			echo 'mutable-loop:pass' . PHP_EOL;
		} else {
			echo 'mutable-loop:fail' . PHP_EOL;
		}
		$values = array(
			3,
			1,
			4,
		);
		$selected = $values[ 1 ] + $values[ 2 ];
		if ( $selected === 5 ) {
			echo 'int-array-read:pass' . PHP_EOL;
		} else {
			echo 'int-array-read:fail' . PHP_EOL;
		}
		$label = 'Haxe ' . '→ PHP 🚀';
		echo $label . PHP_EOL;
		if ( $label === 'Haxe → PHP 🚀' ) {
			echo 'unicode-string:pass' . PHP_EOL;
		} else {
			echo 'unicode-string:fail' . PHP_EOL;
		}
	}
}
