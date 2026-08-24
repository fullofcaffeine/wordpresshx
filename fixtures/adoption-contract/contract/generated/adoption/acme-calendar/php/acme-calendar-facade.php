<?php

declare(strict_types=1);

final class WordPressHxAcmeCalendarProviderUnavailable extends RuntimeException {}

final class WordPressHxAcmeCalendarVerifiedProvider
{
    public function __construct(
        public readonly string $bundleDigest
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
        if (!hash_equals($match[1], hash('sha256', $material))) {
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
        $expectedStaticMembers = json_decode('[{"path":"generated/adoption/acme-calendar/capability.json","role":"capability","sha256":"16a6fcd44dd10f02c5b9cef1386e595e6744531633107355eab36f94d74183eb","sizeBytes":2234},{"path":"generated/adoption/acme-calendar/contract.json","role":"contract","sha256":"6ea0366d8645c8a53595f3bffcaed8267c28b0e74d03d7c2c7b3a3d33f0cba3e","sizeBytes":8278},{"path":"generated/adoption/acme-calendar/haxe/wordpress/hx/adoption/prototype/generated/GeneratedAcmeCalendar.hx","role":"haxe-facade","sha256":"a7c121fec1004591ce6f600ff63c26815ace98c49c493ce3da3f9974a88ffc62","sizeBytes":2682},{"path":"generated/adoption/acme-calendar/provider/acme-calendar.2.4.1.zip","role":"provider-artifact","sha256":"923412beee77cce43964a12358bb099ac07014bd37973df9910de3ad15b9cabd","sizeBytes":1549},{"path":"generated/adoption/acme-calendar/review.json","role":"review","sha256":"6d12c71f00ebfaf43eb96ede3889a43a7236ecf9f277eaea20820675aceca325","sizeBytes":4785}]', true, 512, JSON_THROW_ON_ERROR);
        $members = $bundle['members'] ?? null;
        if (!is_array($expectedStaticMembers) || !is_array($members) || count($members) !== 7) {
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
        foreach ([
            'javascript-facade' => 'generated/adoption/acme-calendar/browser/acme-calendar-facade.mjs',
            'php-facade' => 'generated/adoption/acme-calendar/php/acme-calendar-facade.php',
        ] as $role => $path) {
            $member = $membersByRole[$role] ?? null;
            if (!is_array($member)
                || ($member['path'] ?? null) !== $path
                || preg_match('/^[0-9a-f]{64}$/', $member['sha256'] ?? '') !== 1
                || !is_int($member['sizeBytes'] ?? null)
                || $member['sizeBytes'] <= 0) {
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
        return new WordPressHxAcmeCalendarVerifiedProvider($bundleDigest);
    }

    /** @return list<string> */
    public static function listEventTitles(
        WordPressHxAcmeCalendarVerifiedProvider $provider,
        int $limit
    ): array {
        return $provider->listEventTitles($limit);
    }
}
