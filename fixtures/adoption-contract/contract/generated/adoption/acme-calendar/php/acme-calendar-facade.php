<?php

declare(strict_types=1);

final class WordPressHxAcmeCalendarProviderUnavailable extends RuntimeException {}

final class WordPressHxAcmeCalendarVerifiedProvider
{
    public function __construct(
        public readonly string $bundleDigest,
        public readonly string $executableClosureSha256
    ) {}

    /** @return list<string> */
    public function listEventTitles(int $limit): array
    {
        try {
            $events = \Acme\Calendar\list_events($limit);
        } catch (Throwable $failure) {
            throw new RuntimeException('provider-call-failed', 0, $failure);
        }
        $titles = [];
        foreach ($events as $event) {
            if (!$event instanceof \Acme\Calendar\Event) {
                throw new UnexpectedValueException('provider-returned-wrong-event');
            }
            $titles[] = $event->title();
        }
        return $titles;
    }
}

final class WordPressHxAcmeCalendarFacade
{
    private static function verifyBundle(string $bundleFile): string
    {
        if (!is_file($bundleFile)) {
            throw new WordPressHxAcmeCalendarProviderUnavailable('content-bundle-absent');
        }
        $bytes = file_get_contents($bundleFile);
        if (!is_string($bytes) || !str_ends_with($bytes, "\n")) {
            throw new WordPressHxAcmeCalendarProviderUnavailable('wrong-content-bundle');
        }
        $canonical = substr($bytes, 0, -1);
        if (preg_match('/^\{"bundleDigest":"([0-9a-f]{64})",/', $canonical, $match) !== 1
            || !isset($match[0], $match[1])) {
            throw new WordPressHxAcmeCalendarProviderUnavailable('wrong-content-bundle');
        }
        $material = '{' . substr($canonical, strlen($match[0]));
        if (!hash_equals($match[1], hash('sha256', $material))
            || !hash_equals('2c1dfaffcafce7cb9929c10ce1a25bf882a6580e41ba82365e043b1770221007', $match[1])) {
            throw new WordPressHxAcmeCalendarProviderUnavailable('wrong-content-bundle');
        }
        try {
            $bundle = json_decode($canonical, true, 512, JSON_THROW_ON_ERROR);
        } catch (JsonException $failure) {
            throw new WordPressHxAcmeCalendarProviderUnavailable('wrong-content-bundle', 0, $failure);
        }
        if (!is_array($bundle)
            || ($bundle['schema'] ?? null) !== 'wordpress-hx.adoption-bundle.v1'
            || ($bundle['schemaVersion'] ?? null) !== 1
            || ($bundle['bundleId'] ?? null) !== 'acme-calendar.wp70.bundle'
            || ($bundle['bundleVersion'] ?? null) !== '1.0.0'
            || ($bundle['provider']['id'] ?? null) !== 'acme-calendar'
            || ($bundle['provider']['version'] ?? null) !== '2.4.1'
            || ($bundle['provider']['artifactSha256'] ?? null) !== '923412beee77cce43964a12358bb099ac07014bd37973df9910de3ad15b9cabd') {
            throw new WordPressHxAcmeCalendarProviderUnavailable('wrong-content-bundle');
        }
        $expectedStaticMembers = json_decode('[{"path":"generated/adoption/acme-calendar/capability.json","role":"capability","sha256":"a2239ce37c8a49521051e0f1475e7c336000b862bb19d8d95c2b3453585d6886","sizeBytes":2477},{"path":"generated/adoption/acme-calendar/contract.json","role":"contract","sha256":"b18b8541bd1758128be38606b4375e5803b55bf03fd5e5aed4fe0ee825a11553","sizeBytes":8278},{"path":"generated/adoption/acme-calendar/haxe/wordpress/hx/adoption/prototype/generated/GeneratedAcmeCalendar.hx","role":"haxe-facade","sha256":"59c4729d6606960a318c6517e912fb000892ffe5e26ea23d5a40fc2e38274b35","sizeBytes":2898},{"path":"generated/adoption/acme-calendar/provider/acme-calendar.2.4.1.zip","role":"provider-artifact","sha256":"923412beee77cce43964a12358bb099ac07014bd37973df9910de3ad15b9cabd","sizeBytes":1549},{"path":"generated/adoption/acme-calendar/review.json","role":"review","sha256":"a6c79251b7476f9f3e24f476afdbe9f119c1bbcbfdba9cbd79c1515dd656170a","sizeBytes":4785}]', true, 512, JSON_THROW_ON_ERROR);
        $members = $bundle['members'] ?? null;
        if (!is_array($expectedStaticMembers) || !is_array($members) || count($members) !== 5) {
            throw new WordPressHxAcmeCalendarProviderUnavailable('wrong-content-bundle');
        }
        $membersByRole = [];
        foreach ($members as $member) {
            if (!is_array($member)
                || array_keys($member) !== ['path', 'role', 'sha256', 'sizeBytes']
                || !is_string($member['role'])
                || isset($membersByRole[$member['role']])) {
                throw new WordPressHxAcmeCalendarProviderUnavailable('wrong-content-bundle');
            }
            $membersByRole[$member['role']] = $member;
        }
        foreach ($expectedStaticMembers as $expected) {
            if (!is_array($expected)
                || !is_string($expected['role'] ?? null)
                || ($membersByRole[$expected['role']] ?? null) != $expected) {
                throw new WordPressHxAcmeCalendarProviderUnavailable('wrong-content-bundle');
            }
        }
        $bundleSuffix = 'generated/adoption/acme-calendar/adoption.bundle.json';
        if (!str_ends_with($bundleFile, $bundleSuffix)) {
            throw new WordPressHxAcmeCalendarProviderUnavailable('wrong-content-bundle');
        }
        $outputRoot = substr($bundleFile, 0, -strlen($bundleSuffix));
        foreach ($expectedStaticMembers as $expected) {
            $memberFile = $outputRoot . $expected['path'];
            $memberBytes = is_file($memberFile) ? file_get_contents($memberFile) : false;
            if (!is_string($memberBytes)
                || strlen($memberBytes) !== $expected['sizeBytes']
                || !hash_equals($expected['sha256'], hash('sha256', $memberBytes))) {
                throw new WordPressHxAcmeCalendarProviderUnavailable('wrong-content-bundle');
            }
        }
        return $match[1];
    }

    public static function open(
        string $pluginFile,
        string $bundleFile
    ): WordPressHxAcmeCalendarVerifiedProvider {
        $bundleDigest = self::verifyBundle($bundleFile);
        if (!is_file($pluginFile)) {
            throw new WordPressHxAcmeCalendarProviderUnavailable('provider-absent');
        }
        $bytes = file_get_contents($pluginFile);
        if (!is_string($bytes) || !hash_equals('8d87130bc484658004329fcdf7b603d82f697b49169d119c05758e0ac014d203', hash('sha256', $bytes))) {
            throw new WordPressHxAcmeCalendarProviderUnavailable('wrong-provider-artifact');
        }
        if (preg_match('/^Version:\s*([^\s]+)$/m', $bytes, $match) !== 1
            || !isset($match[1])
            || $match[1] !== '2.4.1') {
            throw new WordPressHxAcmeCalendarProviderUnavailable('wrong-provider-version');
        }
        if (!str_starts_with($bytes, '<?php')) {
            throw new WordPressHxAcmeCalendarProviderUnavailable('wrong-provider-artifact');
        }
        eval(substr($bytes, 5));
        if (!function_exists('Acme\\Calendar\\list_events')
            || !class_exists('Acme\\Calendar\\Event', false)) {
            throw new WordPressHxAcmeCalendarProviderUnavailable('required-provider-symbol-missing');
        }
        return new WordPressHxAcmeCalendarVerifiedProvider($bundleDigest, '8d87130bc484658004329fcdf7b603d82f697b49169d119c05758e0ac014d203');
    }

    /** @return list<string> */
    public static function listEventTitles(
        WordPressHxAcmeCalendarVerifiedProvider $provider,
        int $limit
    ): array {
        return $provider->listEventTitles($limit);
    }
}
