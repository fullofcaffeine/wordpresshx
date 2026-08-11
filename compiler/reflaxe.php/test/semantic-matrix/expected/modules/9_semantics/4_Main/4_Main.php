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
			$total = \ReflaxePhpInt32Runtime::add( $total, $current );
			$current = \ReflaxePhpInt32Runtime::add( $current, 1 );
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
		$selected = \ReflaxePhpInt32Runtime::add( $values[ 1 ], $values[ 2 ] );
		if ( $selected === 5 ) {
			echo 'int-array-read:pass' . PHP_EOL;
		} else {
			echo 'int-array-read:fail' . PHP_EOL;
		}
		$label = Hx_9_semantics_10_Calculator::decorate( 'Haxe ', '→ PHP 🚀' );
		echo $label . PHP_EOL;
		if ( $label === 'Haxe → PHP 🚀' ) {
			echo 'unicode-string:pass' . PHP_EOL;
		} else {
			echo 'unicode-string:fail' . PHP_EOL;
		}
		$enabled = Hx_9_semantics_10_Calculator::negate( false );
		if ( $enabled ) {
			echo 'bool-control:pass' . PHP_EOL;
		} else {
			echo 'bool-control:fail' . PHP_EOL;
		}
		$andSkipped = ( false && Hx_9_semantics_10_Calculator::probe( true ) );
		$orSkipped = ( true || Hx_9_semantics_10_Calculator::probe( false ) );
		$andEvaluated = ( true && Hx_9_semantics_10_Calculator::probe( false ) );
		$grouped = ( ( true || Hx_9_semantics_10_Calculator::probe( false ) ) && false );
		if ( ( ( ( ! $andSkipped && $orSkipped ) && ! $andEvaluated ) && ! $grouped ) ) {
			echo 'bool-short-circuit:pass' . PHP_EOL;
		} else {
			echo 'bool-short-circuit:fail' . PHP_EOL;
		}
		$greeter = new Hx_9_semantics_7_Greeter( 'instance-layout:' );
		echo $greeter->render( 'pass' ) . PHP_EOL;
		$prefix = 'closure-capture:';
		$render = static function (string $value) use ($prefix): string {
			return $prefix . $value;
		};
		echo $render( 'pass' ) . PHP_EOL;
		try {
			throw new \RuntimeException( 'expected-exception' );
		} catch (\RuntimeException $error) {
			$message = $error->getMessage();
			if ( $message === 'expected-exception' ) {
				echo 'exception-catch:pass' . PHP_EOL;
			} else {
				echo 'exception-catch:fail' . PHP_EOL;
			}
		}
		$missing = null;
		$present = 'present';
		if ( ( ( ( Hx_9_semantics_10_Calculator::isMissing( $missing ) && Hx_9_semantics_10_Calculator::isPresent( $present ) ) && Hx_9_semantics_10_Calculator::isMissing( null ) ) && Hx_9_semantics_10_Calculator::isPresent( 'direct' ) ) ) {
			echo 'nullable-string:pass' . PHP_EOL;
		} else {
			echo 'nullable-string:fail' . PHP_EOL;
		}
		$returnedMissing = Hx_9_semantics_10_Calculator::roundTrip( $missing );
		$returnedPresent = Hx_9_semantics_10_Calculator::roundTrip( $present );
		if ( ( Hx_9_semantics_10_Calculator::isMissing( $returnedMissing ) && Hx_9_semantics_10_Calculator::isPresent( $returnedPresent ) ) ) {
			echo 'nullable-string-return:pass' . PHP_EOL;
		} else {
			echo 'nullable-string-return:fail' . PHP_EOL;
		}
		$unicodeLength = \ReflaxePhpStringRuntime::length( 'A🚀' );
		if ( $unicodeLength === 2 ) {
			echo 'unicode-string-length:pass' . PHP_EOL;
		} else {
			echo 'unicode-string-length:fail' . PHP_EOL;
		}
		$valueCount = \count( $values );
		if ( $valueCount === 3 ) {
			echo 'int-array-length:pass' . PHP_EOL;
		} else {
			echo 'int-array-length:fail' . PHP_EOL;
		}
		$values[] = 5;
		$pushedCount = \count( $values );
		$pushedValue = $values[ 3 ];
		$pushedSummary = \ReflaxePhpInt32Runtime::add( $pushedCount, $pushedValue );
		if ( $pushedSummary === 9 ) {
			echo 'int-array-push:pass' . PHP_EOL;
		} else {
			echo 'int-array-push:fail' . PHP_EOL;
		}
		$values[ 1 ] = 5;
		$writtenCount = \count( $values );
		$writtenValue = $values[ 1 ];
		$writtenSummary = \ReflaxePhpInt32Runtime::add( $writtenCount, $writtenValue );
		if ( $writtenSummary === 9 ) {
			echo 'int-array-write:pass' . PHP_EOL;
		} else {
			echo 'int-array-write:fail' . PHP_EOL;
		}
		\array_pop( $values );
		$poppedCount = \count( $values );
		$poppedValue = $values[ 2 ];
		$poppedSummary = \ReflaxePhpInt32Runtime::add( $poppedCount, $poppedValue );
		if ( $poppedSummary === 7 ) {
			echo 'int-array-pop:pass' . PHP_EOL;
		} else {
			echo 'int-array-pop:fail' . PHP_EOL;
		}
		$leftAssociated = 9 - 4 - 2;
		$groupedSubtraction = 9 - ( 4 - 2 );
		$subtractionSummary = \ReflaxePhpInt32Runtime::add( $leftAssociated, $groupedSubtraction );
		if ( $subtractionSummary === 10 ) {
			echo 'int-subtraction-grouping:pass' . PHP_EOL;
		} else {
			echo 'int-subtraction-grouping:fail' . PHP_EOL;
		}
		$multipliedByPrecedence = 2 + 3 * 4;
		$multipliedAfterGrouping = ( 2 + 3 ) * 4;
		$multiplicationSummary = \ReflaxePhpInt32Runtime::add( $multipliedByPrecedence, $multipliedAfterGrouping );
		if ( $multiplicationSummary === 34 ) {
			echo 'int-multiplication-grouping:pass' . PHP_EOL;
		} else {
			echo 'int-multiplication-grouping:fail' . PHP_EOL;
		}
		if ( 3 < 5 ) {
			if ( 5 > 3 ) {
				if ( 5 >= 5 ) {
					echo 'int-ordering-comparisons:pass' . PHP_EOL;
				} else {
					echo 'int-ordering-comparisons:fail' . PHP_EOL;
				}
			} else {
				echo 'int-ordering-comparisons:fail' . PHP_EOL;
			}
		} else {
			echo 'int-ordering-comparisons:fail' . PHP_EOL;
		}
		$negatedGrouped = - ( 2 + 3 );
		$nestedNegation = - ( -3 );
		$negationSummary = \ReflaxePhpInt32Runtime::add( $negatedGrouped, $nestedNegation );
		if ( $negationSummary === -2 ) {
			echo 'int-unary-negation:pass' . PHP_EOL;
		} else {
			echo 'int-unary-negation:fail' . PHP_EOL;
		}
		$positiveRemainder = 17 % 5;
		$negativeDividendRemainder = -17 % 5;
		$negativeDivisorRemainder = 17 % -5;
		$groupedRemainder = ( 9 + 8 ) % ( 2 + 3 );
		$minimumRemainder = ( -2147483647 - 1 ) % -1;
		$remainderSummary = \ReflaxePhpInt32Runtime::add( \ReflaxePhpInt32Runtime::add( \ReflaxePhpInt32Runtime::add( \ReflaxePhpInt32Runtime::add( $positiveRemainder, $negativeDividendRemainder ), $negativeDivisorRemainder ), $groupedRemainder ), $minimumRemainder );
		if ( $remainderSummary === 4 ) {
			echo 'int-remainder:pass' . PHP_EOL;
		} else {
			echo 'int-remainder:fail' . PHP_EOL;
		}
		$positiveQuotient = \intdiv( 7, 2 );
		$negativeDividendQuotient = \intdiv( -7, 2 );
		$negativeDivisorQuotient = \intdiv( 7, -2 );
		$groupedQuotient = \intdiv( ( 9 + 7 ), ( 2 + 2 ) );
		$minimumQuotient = \intdiv( ( -2147483647 - 1 ), 1 );
		$divisionSummary = \ReflaxePhpInt32Runtime::add( \ReflaxePhpInt32Runtime::add( \ReflaxePhpInt32Runtime::add( $positiveQuotient, $negativeDividendQuotient ), $negativeDivisorQuotient ), $groupedQuotient );
		if ( $divisionSummary === 1 ) {
			if ( $minimumQuotient === ( -2147483647 - 1 ) ) {
				echo 'int-division-truncation:pass' . PHP_EOL;
			} else {
				echo 'int-division-truncation:fail' . PHP_EOL;
			}
		} else {
			echo 'int-division-truncation:fail' . PHP_EOL;
		}
		$wrappedMaximum = Hx_9_semantics_10_Calculator::add( 2147483647, 1 );
		$wrappedMinimum = Hx_9_semantics_10_Calculator::subtract( -2147483647 - 1, 1 );
		$ordinaryDifference = Hx_9_semantics_10_Calculator::subtract( 12, 5 );
		if ( $wrappedMaximum === ( -2147483647 - 1 ) ) {
			if ( $wrappedMinimum === 2147483647 ) {
				if ( $ordinaryDifference === 7 ) {
					echo 'int-runtime-overflow:pass' . PHP_EOL;
				} else {
					echo 'int-runtime-overflow:fail' . PHP_EOL;
				}
			} else {
				echo 'int-runtime-overflow:fail' . PHP_EOL;
			}
		} else {
			echo 'int-runtime-overflow:fail' . PHP_EOL;
		}
		$ordinaryProduct = Hx_9_semantics_10_Calculator::multiply( 7, 6 );
		$wrappedProduct = Hx_9_semantics_10_Calculator::multiply( 2147483647, 2 );
		$minimumProduct = Hx_9_semantics_10_Calculator::multiply( -2147483647 - 1, -1 );
		$squareProduct = Hx_9_semantics_10_Calculator::multiply( 46341, 46341 );
		if ( $ordinaryProduct === 42 ) {
			if ( $wrappedProduct === -2 ) {
				if ( $minimumProduct === ( -2147483647 - 1 ) ) {
					if ( $squareProduct === -2147479015 ) {
						echo 'int-runtime-multiplication:pass' . PHP_EOL;
					} else {
						echo 'int-runtime-multiplication:fail' . PHP_EOL;
					}
				} else {
					echo 'int-runtime-multiplication:fail' . PHP_EOL;
				}
			} else {
				echo 'int-runtime-multiplication:fail' . PHP_EOL;
			}
		} else {
			echo 'int-runtime-multiplication:fail' . PHP_EOL;
		}
		$ordinaryNegation = Hx_9_semantics_10_Calculator::negateInt( 3 );
		$minimumNegation = Hx_9_semantics_10_Calculator::negateInt( -2147483647 - 1 );
		if ( $ordinaryNegation === -3 ) {
			if ( $minimumNegation === ( -2147483647 - 1 ) ) {
				echo 'int-runtime-negation:pass' . PHP_EOL;
			} else {
				echo 'int-runtime-negation:fail' . PHP_EOL;
			}
		} else {
			echo 'int-runtime-negation:fail' . PHP_EOL;
		}
		$positiveRuntimeRemainder = Hx_9_semantics_10_Calculator::remainderByFive( 17 );
		$negativeRuntimeRemainder = Hx_9_semantics_10_Calculator::remainderByFive( -17 );
		$minimumRuntimeRemainder = Hx_9_semantics_10_Calculator::remainderByFive( -2147483647 - 1 );
		if ( $positiveRuntimeRemainder === 2 ) {
			if ( $negativeRuntimeRemainder === -2 ) {
				if ( $minimumRuntimeRemainder === -3 ) {
					echo 'int-runtime-remainder:pass' . PHP_EOL;
				} else {
					echo 'int-runtime-remainder:fail' . PHP_EOL;
				}
			} else {
				echo 'int-runtime-remainder:fail' . PHP_EOL;
			}
		} else {
			echo 'int-runtime-remainder:fail' . PHP_EOL;
		}
		$positiveRuntimeQuotient = Hx_9_semantics_10_Calculator::divideByTwo( 17 );
		$negativeRuntimeQuotient = Hx_9_semantics_10_Calculator::divideByTwo( -17 );
		$wrappedRuntimeQuotient = Hx_9_semantics_10_Calculator::divideByNegativeOne( -2147483647 - 1 );
		if ( $positiveRuntimeQuotient === 8 ) {
			if ( $negativeRuntimeQuotient === -8 ) {
				if ( $wrappedRuntimeQuotient === ( -2147483647 - 1 ) ) {
					echo 'int-runtime-division:pass' . PHP_EOL;
				} else {
					echo 'int-runtime-division:fail' . PHP_EOL;
				}
			} else {
				echo 'int-runtime-division:fail' . PHP_EOL;
			}
		} else {
			echo 'int-runtime-division:fail' . PHP_EOL;
		}
	}
}
