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
    $result = CanonicalWireJson::encodeChecked($value);
    if (1 !== $result->index) {
        throw new RuntimeException($label . ' emitted bytes');
    }
    if ($expectedReason !== ($result->params[0] ?? null)) {
        throw new RuntimeException($label . ' returned a different reason');
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

echo "PHP foreign WireValue rejection passed\n";
