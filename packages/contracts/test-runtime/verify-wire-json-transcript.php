<?php

declare(strict_types=1);

$transcriptPath = $argv[1] ?? '';
if ('' === $transcriptPath) {
    throw new RuntimeException('wire JSON transcript is required');
}
$lines = file($transcriptPath, FILE_IGNORE_NEW_LINES);
if (false === $lines) {
    throw new RuntimeException('wire JSON transcript is not readable');
}

$encodedCount = 0;
foreach ($lines as $line) {
    $marker = '=encoded:';
    $separator = strpos($line, $marker);
    if (false === $separator) {
        continue;
    }
    json_decode(substr($line, $separator + strlen($marker)), true, 512, JSON_THROW_ON_ERROR);
    $encodedCount++;
}
if (0 === $encodedCount) {
    throw new RuntimeException('wire JSON transcript has no encoded vectors');
}

echo 'PHP decoded ' . $encodedCount . " wire JSON vectors\n";
