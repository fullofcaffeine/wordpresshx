<?php

declare(strict_types=1);

use wordpress\hx\contracts\CanonicalWireJson;
use wordpress\hx\contracts\WireValue;

$generatedRoot = $argv[1] ?? '';
if ('' === $generatedRoot) {
    throw new RuntimeException('generated PHP root is required');
}

ob_start();
require $generatedRoot . '/index.php';
ob_end_clean();

function wordpresshx_expect_rejected(string $label, WireValue $value, string $expectedReason): void
{
    wordpresshx_assert_rejected($label, CanonicalWireJson::encodeChecked($value), $expectedReason);
}

function wordpresshx_assert_rejected(string $label, $result, string $expectedReason): void
{
    if (1 !== $result->index) {
        throw new RuntimeException($label . ' emitted bytes');
    }
    if ($expectedReason !== ($result->params[0] ?? null)) {
        throw new RuntimeException($label . ' returned a different reason');
    }
}

function wordpresshx_expect_rejected_at_depth(string $label, WireValue $value, $maxDepth, string $expectedReason): void
{
    wordpresshx_assert_rejected(
        $label,
        CanonicalWireJson::encodeChecked($value, $maxDepth),
        $expectedReason
    );
}

function wordpresshx_nested_arrays(int $count): WireValue
{
    $value = WireValue::NullValue();
    for ($index = 0; $index < $count; $index++) {
        $value = WireValue::ArrayValue(\Array_hx::wrap([$value]));
    }
    return $value;
}

final class WordPressHxThrowingArrayAccess implements ArrayAccess
{
    #[\ReturnTypeWillChange]
    public function offsetExists($offset)
    {
        return true;
    }

    #[\ReturnTypeWillChange]
    public function offsetGet($offset)
    {
        throw new RuntimeException('wire-array-getter');
    }

    #[\ReturnTypeWillChange]
    public function offsetSet($offset, $value)
    {
    }

    #[\ReturnTypeWillChange]
    public function offsetUnset($offset)
    {
    }
}

wordpresshx_expect_rejected('null-bool', WireValue::BoolValue(null), '$: invalid-bool');
wordpresshx_expect_rejected('string-bool', WireValue::BoolValue('true'), '$: invalid-bool');
wordpresshx_expect_rejected('number-bool', WireValue::BoolValue(1), '$: invalid-bool');
wordpresshx_expect_rejected('null-integer', WireValue::IntegerValue(null), '$: invalid-integer');
wordpresshx_expect_rejected('fractional-integer', WireValue::IntegerValue(1.5), '$: invalid-integer');
wordpresshx_expect_rejected('large-integer', WireValue::IntegerValue(2147483648), '$: invalid-integer');
wordpresshx_expect_rejected('small-integer', WireValue::IntegerValue(-2147483649), '$: invalid-integer');
wordpresshx_expect_rejected('nan-integer', WireValue::IntegerValue(NAN), '$: invalid-integer');
wordpresshx_expect_rejected('infinite-integer', WireValue::IntegerValue(INF), '$: invalid-integer');
wordpresshx_expect_rejected('wrong-string', WireValue::StringValue(7), '$: invalid-string');
wordpresshx_expect_rejected('wrong-array', WireValue::ArrayValue(new stdClass()), '$: invalid-array');
wordpresshx_expect_rejected('wrong-object', WireValue::ObjectValue(new stdClass()), '$: invalid-object');
wordpresshx_expect_rejected('unknown-tag', new WireValue('Unknown', 99, array()), '$: invalid-wire-value');
wordpresshx_expect_rejected('valid-index-unknown-tag', new WireValue('Unknown', 0, array()), '$: invalid-wire-value');
wordpresshx_expect_rejected('mismatched-tag-index', new WireValue('BoolValue', 0, array(true)), '$: invalid-wire-value');
wordpresshx_expect_rejected('null-with-parameters', new WireValue('NullValue', 0, array(true)), '$: invalid-wire-value');
wordpresshx_expect_rejected('bool-without-parameters', new WireValue('BoolValue', 1, array()), '$: invalid-wire-value');
wordpresshx_expect_rejected('field-without-name', WireValue::ObjectValue(\Array_hx::wrap([new stdClass()])), '$[0]: invalid-field');
wordpresshx_expect_rejected('field-without-value', WireValue::ObjectValue(\Array_hx::wrap([(object) array('name' => 'valid')])), '$[0]: invalid-field');
wordpresshx_expect_rejected('non-object-field', WireValue::ObjectValue(\Array_hx::wrap([7])), '$[0]: invalid-field');

$nested65 = wordpresshx_nested_arrays(65);
foreach ([
    'nan-depth' => NAN,
    'fractional-depth' => 1.5,
    'string-depth' => '64',
    'boolean-depth' => true,
    'infinite-depth' => INF,
] as $label => $maxDepth) {
    wordpresshx_expect_rejected_at_depth(
        $label,
        $nested65,
        $maxDepth,
        'json-depth-limit-must-be-integer'
    );
}

$cycle = new \Array_hx();
$cycleValue = WireValue::ArrayValue($cycle);
$cycle->push($cycleValue);
wordpresshx_expect_rejected_at_depth(
    'nan-depth-cycle',
    $cycleValue,
    NAN,
    'json-depth-limit-must-be-integer'
);

$throwing = new \Array_hx();
$throwing->arr = new WordPressHxThrowingArrayAccess();
$throwing->length = 1;
wordpresshx_expect_rejected(
    'throwing-array-element',
    WireValue::ArrayValue($throwing),
    '$[0]: invalid-array-element'
);

echo "PHP foreign WireValue rejection passed\n";
