<?php

declare(strict_types=1);

use Composer\InstalledVersions;

const REPORT_SCHEMA = 'wordpress-hx.php-quality-run.v1';
const POLICY_ID = 'wp70-release-generated-php-v1';
const PRIVATE_PREFIX = 'private/wordpresshx/';

$tool_root = __DIR__;
$stage_root = null;
$temporary_root = null;

try {
	if (PHP_VERSION_ID < 70400) {
		throw new RuntimeException('the PHP quality runner requires PHP 7.4 or newer');
	}
	if ($argc !== 2 || !is_string($argv[1]) || $argv[1] === '') {
		throw new RuntimeException('usage: php run.php <complete-plugin-stage>');
	}
	$stage_root = resolve_directory($argv[1], 'complete plugin stage');
	$toolchain_path = $tool_root . '/toolchain.json';
	$toolchain = read_json_object($toolchain_path, 'PHP quality toolchain');
	validate_toolchain($toolchain);
	$autoload_path = $tool_root . '/vendor/autoload.php';
	require_exact_file($autoload_path, 'installed Composer tool graph');
	require $autoload_path;

	$expected_versions = array(
		'dealerdirect/phpcodesniffer-composer-installer' => '1.2.1',
		'php-stubs/wordpress-stubs' => '7.0.0',
		'phpcompatibility/php-compatibility' => '9.3.5',
		'phpcompatibility/phpcompatibility-paragonie' => '1.3.4',
		'phpcompatibility/phpcompatibility-wp' => '2.1.8',
		'phpcsstandards/phpcsextra' => '1.5.0',
		'phpcsstandards/phpcsutils' => '1.2.2',
		'phpstan/phpstan' => '2.2.5',
		'squizlabs/php_codesniffer' => '3.13.5',
		'wp-coding-standards/wpcs' => '3.4.0',
	);
	validate_installed_versions($expected_versions);

	$php_files = collect_php_files($stage_root);
	if (count($php_files) < 3) {
		throw new RuntimeException('generated plugin stage must contain at least three PHP files');
	}
	$public_files = array();
	$private_files = array();
	foreach ($php_files as $relative => $absolute) {
		if (strpos($relative, PRIVATE_PREFIX) === 0) {
			$private_files[$relative] = $absolute;
		} else {
			$public_files[$relative] = $absolute;
		}
	}
	if (count($public_files) < 3) {
		throw new RuntimeException('generated plugin stage omitted its native public PHP boundary');
	}

	$temporary_root = create_private_temporary_directory();
	foreach ($php_files as $relative => $absolute) {
		run_command(array(PHP_BINARY, '-l', $absolute), $tool_root, 'PHP syntax lint for ' . $relative, array(0));
	}
	validate_duplicate_symbols($php_files);

	$format_root = $temporary_root . '/format';
	$format_files = copy_files($public_files, $format_root);
	$phpcbf = $tool_root . '/vendor/bin/phpcbf';
	require_exact_file($phpcbf, 'PHPCBF executable');
	run_command(
		array_merge(
			array(PHP_BINARY, $phpcbf, '--no-colors', '--standard=' . $tool_root . '/phpcs-public.xml', '--basepath=' . $format_root),
			array_keys($format_files)
		),
		$format_root,
		'deterministic PHP formatter',
		array(0, 1, 2)
	);
	foreach ($public_files as $relative => $absolute) {
		if (hash_file('sha256', $absolute) !== hash_file('sha256', $format_files[$relative])) {
			throw new RuntimeException('generated public PHP is not formatter-stable: ' . $relative);
		}
	}

	$phpcs = $tool_root . '/vendor/bin/phpcs';
	require_exact_file($phpcs, 'PHPCS executable');
	run_command(
		array_merge(
			array(PHP_BINARY, $phpcs, '--no-colors', '--report=full', '--standard=' . $tool_root . '/phpcs-public.xml', '--basepath=' . $stage_root),
			array_values($public_files)
		),
		$tool_root,
		'WordPress Coding Standards',
		array(0)
	);
	run_command(
		array_merge(
			array(PHP_BINARY, $phpcs, '--no-colors', '--report=full', '--standard=' . $tool_root . '/phpcs-compat.xml', '--basepath=' . $stage_root),
			array_values($public_files)
		),
		$tool_root,
		'public PHP 7.4 compatibility',
		array(0)
	);
	if (count($private_files) > 0) {
		run_command(
			array_merge(
				array(PHP_BINARY, $phpcs, '--no-colors', '--report=full', '--standard=' . $tool_root . '/phpcs-compat-private.xml', '--basepath=' . $stage_root),
				array_values($private_files)
			),
			$tool_root,
			'private PHP 7.4 compatibility',
			array(0)
		);
	}

	$classmap_path = $stage_root . '/' . PRIVATE_PREFIX . 'classmap.php';
	$classmap = count($private_files) === 0 ? array() : validate_classmap($stage_root, $classmap_path, $private_files);
	$autoload_bootstrap = null;
	if (count($classmap) > 0) {
		$autoload_bootstrap = write_phpstan_autoload($temporary_root, $classmap_path);
	}

	$phpstan = $tool_root . '/vendor/bin/phpstan';
	require_exact_file($phpstan, 'PHPStan executable');
	$public_phpstan = array(
		PHP_BINARY,
		$phpstan,
		'analyse',
		'--debug',
		'--no-progress',
		'--memory-limit=512M',
		'--error-format=raw',
		'--configuration=' . $tool_root . '/phpstan-public.neon',
	);
	if ($autoload_bootstrap !== null) {
		$public_phpstan[] = '--autoload-file=' . $autoload_bootstrap;
	}
	run_command(array_merge($public_phpstan, array_values($public_files)), $tool_root, 'PHPStan public level 6', array(0));
	if (count($private_files) > 0) {
		run_command(
			array_merge(
				array(
					PHP_BINARY,
					$phpstan,
					'analyse',
					'--debug',
					'--no-progress',
					'--memory-limit=512M',
					'--error-format=raw',
					'--configuration=' . $tool_root . '/phpstan-private.neon',
				),
				array_values($private_files)
			),
			$tool_root,
			'PHPStan private level 0',
			array(0)
		);
	}

	$autoload_probe = write_autoload_probe($temporary_root, $stage_root, $classmap_path, count($private_files) > 0);
	run_command(array(PHP_BINARY, $autoload_probe), $tool_root, 'generated autoload closure', array(0));

	$policy_paths = array(
		'composer.json',
		'composer.lock',
		'phpcs-compat-private.xml',
		'phpcs-compat.xml',
		'phpcs-public.xml',
		'phpstan-private.neon',
		'phpstan-public.neon',
		'run.php',
		'toolchain.json',
	);
	$policy_sha256 = digest_files($tool_root, $policy_paths);
	$report = array(
		'autoloadMode' => count($private_files) > 0 ? 'authoritative-private-classmap' : 'native-require-closure',
		'classmapEntries' => count($classmap),
		'composerLockSha256' => hash_file('sha256', $tool_root . '/composer.lock'),
		'formatChangedFiles' => 0,
		'phpFileCount' => count($php_files),
		'phpStanPrivateLevel' => count($private_files) > 0 ? 0 : -1,
		'phpStanPublicLevel' => 6,
		'policyId' => POLICY_ID,
		'policySha256' => $policy_sha256,
		'privatePhpFileCount' => count($private_files),
		'publicPhpFileCount' => count($public_files),
		'schema' => REPORT_SCHEMA,
		'status' => 'passed',
		'wordpressStubsSha256' => hash_file('sha256', $tool_root . '/vendor/php-stubs/wordpress-stubs/wordpress-stubs.php'),
	);
	ksort($report, SORT_STRING);
	foreach ($report as $name => $value) {
		if (is_int($value)) {
			echo $name . '=' . (string) $value . "\n";
		} elseif (is_string($value)) {
			echo $name . '=' . $value . "\n";
		} else {
			throw new RuntimeException('quality report contains an unsupported scalar');
		}
	}
	remove_tree($temporary_root);
	$temporary_root = null;
} catch (Throwable $failure) {
	$message = $failure->getMessage();
	$private_paths = array();
	foreach (array($stage_root, $tool_root, $temporary_root) as $private_path) {
		if (is_string($private_path) && $private_path !== '') {
			$private_paths[] = $private_path;
			$canonical_path = realpath($private_path);
			if (is_string($canonical_path) && $canonical_path !== $private_path) {
				$private_paths[] = $canonical_path;
			}
		}
	}
	usort($private_paths, static function (string $left, string $right): int {
		return strlen($right) <=> strlen($left);
	});
	if ($temporary_root !== null && is_dir($temporary_root)) {
		remove_tree($temporary_root);
	}
	foreach ($private_paths as $private_path) {
		$message = str_replace($private_path, '<private-root>', $message);
	}
	$message = preg_replace('/[\r\n]+/', ' | ', $message);
	fwrite(STDERR, 'WPHX3400 ' . trim((string) $message) . "\n");
	exit(6);
}

function resolve_directory(string $path, string $label): string
{
	$resolved = realpath($path);
	if ($resolved === false || !is_dir($resolved) || is_link($path)) {
		throw new RuntimeException($label . ' must be a real directory');
	}
	return $resolved;
}

function require_exact_file(string $path, string $label): void
{
	if (!is_file($path) || is_link($path)) {
		throw new RuntimeException($label . ' is missing or is not a regular file');
	}
}

/** @return array<string, mixed> */
function read_json_object(string $path, string $label): array
{
	require_exact_file($path, $label);
	$value = json_decode((string) file_get_contents($path), true, 512, JSON_THROW_ON_ERROR);
	if (!is_array($value) || array_values($value) === $value) {
		throw new RuntimeException($label . ' must be a JSON object');
	}
	return $value;
}

/** @param array<string, mixed> $toolchain */
function validate_toolchain(array $toolchain): void
{
	if (($toolchain['schema'] ?? null) !== 'wordpress-hx.php-quality-toolchain.v1'
		|| ($toolchain['policyId'] ?? null) !== POLICY_ID) {
		throw new RuntimeException('PHP quality toolchain identity is invalid');
	}
}

/** @param array<string, string> $expected */
function validate_installed_versions(array $expected): void
{
	foreach ($expected as $package => $version) {
		if (!InstalledVersions::isInstalled($package)) {
			throw new RuntimeException('installed PHP quality graph omitted ' . $package);
		}
		$actual = InstalledVersions::getPrettyVersion($package);
		if (!is_string($actual) || ltrim($actual, 'v') !== ltrim($version, 'v')) {
			throw new RuntimeException('installed PHP quality graph has the wrong version for ' . $package);
		}
	}
}

/** @return array<string, string> */
function collect_php_files(string $root): array
{
	$result = array();
	$iterator = new RecursiveIteratorIterator(
		new RecursiveDirectoryIterator($root, FilesystemIterator::SKIP_DOTS),
		RecursiveIteratorIterator::SELF_FIRST
	);
	foreach ($iterator as $item) {
		/** @var SplFileInfo $item */
		if ($item->isLink()) {
			throw new RuntimeException('generated plugin stage contains a symbolic link');
		}
		if ($item->isDir()) {
			continue;
		}
		if (!$item->isFile()) {
			throw new RuntimeException('generated plugin stage contains a special file');
		}
		$absolute = $item->getPathname();
		$relative = str_replace(DIRECTORY_SEPARATOR, '/', substr($absolute, strlen($root) + 1));
		if (substr($relative, -4) === '.php') {
			$result[$relative] = $absolute;
		}
	}
	ksort($result, SORT_STRING);
	return $result;
}

function create_private_temporary_directory(): string
{
	$root = rtrim(sys_get_temp_dir(), DIRECTORY_SEPARATOR)
		. DIRECTORY_SEPARATOR
		. 'wordpresshx-php-quality-'
		. bin2hex(random_bytes(12));
	if (!mkdir($root, 0700) || !is_dir($root)) {
		throw new RuntimeException('could not create the private PHP quality stage');
	}
	$canonical = realpath($root);
	if (!is_string($canonical)) {
		throw new RuntimeException('could not resolve the private PHP quality stage');
	}
	return $canonical;
}

/**
 * @param array<string, string> $files
 * @return array<string, string>
 */
function copy_files(array $files, string $destination_root): array
{
	$result = array();
	foreach ($files as $relative => $source) {
		$destination = $destination_root . '/' . $relative;
		$directory = dirname($destination);
		if (!is_dir($directory) && !mkdir($directory, 0700, true) && !is_dir($directory)) {
			throw new RuntimeException('could not create the private formatter stage');
		}
		if (!copy($source, $destination)) {
			throw new RuntimeException('could not copy generated PHP into the formatter stage');
		}
		chmod($destination, 0600);
		$result[$relative] = $destination;
	}
	return $result;
}

/**
 * @param list<string> $command
 * @param list<int> $accepted_statuses
 */
function run_command(array $command, string $cwd, string $label, array $accepted_statuses): void
{
	$descriptors = array(
		0 => array('pipe', 'r'),
		1 => array('pipe', 'w'),
		2 => array('pipe', 'w'),
	);
	$pipes = array();
	$process = proc_open($command, $descriptors, $pipes, $cwd, null, array('bypass_shell' => true));
	if (!is_resource($process)) {
		throw new RuntimeException('could not start ' . $label);
	}
	fclose($pipes[0]);
	$stdout = stream_get_contents($pipes[1]);
	$stderr = stream_get_contents($pipes[2]);
	fclose($pipes[1]);
	fclose($pipes[2]);
	$status = proc_close($process);
	if (!in_array($status, $accepted_statuses, true)) {
		$transcript = trim((string) $stdout . "\n" . (string) $stderr);
		throw new RuntimeException($label . ' failed' . ($transcript === '' ? '' : ': ' . $transcript));
	}
}

/**
 * @param array<string, string> $private_files
 * @return array<string, string>
 */
function validate_classmap(string $stage_root, string $classmap_path, array $private_files): array
{
	require_exact_file($classmap_path, 'private PHP classmap');
	$classmap = require $classmap_path;
	if (!is_array($classmap) || count($classmap) === 0) {
		throw new RuntimeException('private PHP classmap must be a non-empty array');
	}
	$runtime_root = realpath($stage_root . '/' . PRIVATE_PREFIX . 'runtime');
	if ($runtime_root === false || !is_dir($runtime_root)) {
		throw new RuntimeException('private PHP runtime root is missing');
	}
	$normalized = array();
	$mapped_paths = array();
	foreach ($classmap as $class_name => $mapped_path) {
		if (!is_string($class_name)
			|| preg_match('/^[A-Za-z_][A-Za-z0-9_]*(?:\\\\[A-Za-z_][A-Za-z0-9_]*)*$/D', $class_name) !== 1
			|| !is_string($mapped_path)) {
			throw new RuntimeException('private PHP classmap contains an invalid entry');
		}
		$resolved = realpath($mapped_path);
		if ($resolved === false
			|| !is_file($resolved)
			|| is_link($mapped_path)
			|| strpos($resolved, $runtime_root . DIRECTORY_SEPARATOR) !== 0) {
			throw new RuntimeException('private PHP classmap entry escapes its runtime root');
		}
		$canonical = strtolower($class_name);
		if (isset($normalized[$canonical]) || isset($mapped_paths[$resolved])) {
			throw new RuntimeException('private PHP classmap contains a duplicate symbol or file');
		}
		$symbols = declared_symbols($resolved);
		if (!isset($symbols['class:' . $canonical])) {
			throw new RuntimeException('private PHP classmap key does not match its declaration');
		}
		$normalized[$canonical] = $resolved;
		$mapped_paths[$resolved] = true;
	}
	foreach ($private_files as $relative => $absolute) {
		if ($relative === PRIVATE_PREFIX . 'classmap.php' || substr($relative, -15) === '/_polyfills.php') {
			continue;
		}
		foreach (declared_symbols($absolute) as $symbol => $_file) {
			if (strpos($symbol, 'class:') === 0 && !isset($normalized[substr($symbol, 6)])) {
				throw new RuntimeException('private PHP declaration is absent from its authoritative classmap');
			}
		}
	}
	ksort($classmap, SORT_STRING);
	return $classmap;
}

/** @param array<string, string> $php_files */
function validate_duplicate_symbols(array $php_files): void
{
	$symbols = array();
	foreach ($php_files as $relative => $absolute) {
		foreach (declared_symbols($absolute) as $symbol => $_file) {
			if (isset($symbols[$symbol])) {
				throw new RuntimeException('duplicate PHP symbol ' . $symbol . ' in ' . $symbols[$symbol] . ' and ' . $relative);
			}
			$symbols[$symbol] = $relative;
		}
	}
}

/** @return array<string, string> */
function declared_symbols(string $path): array
{
	$tokens = token_get_all((string) file_get_contents($path));
	$symbols = array();
	$namespace = '';
	$brace_depth = 0;
	$class_depths = array();
	$await_class_brace = false;
	$count = count($tokens);
	for ($index = 0; $index < $count; $index++) {
		$token = $tokens[$index];
		if (is_string($token)) {
			if ($token === '{') {
				$brace_depth++;
				if ($await_class_brace) {
					$class_depths[] = $brace_depth;
					$await_class_brace = false;
				}
			} elseif ($token === '}') {
				if (count($class_depths) > 0 && end($class_depths) === $brace_depth) {
					array_pop($class_depths);
				}
				$brace_depth--;
			}
			continue;
		}
		$id = $token[0];
		if ($id === T_NAMESPACE) {
			$parts = array();
			for ($cursor = $index + 1; $cursor < $count; $cursor++) {
				$candidate = $tokens[$cursor];
				if (is_string($candidate) && ($candidate === ';' || $candidate === '{')) {
					break;
				}
				if (is_array($candidate)
					&& ($candidate[0] === T_STRING
						|| $candidate[0] === T_NS_SEPARATOR
						|| (defined('T_NAME_QUALIFIED') && $candidate[0] === constant('T_NAME_QUALIFIED')))) {
					$parts[] = $candidate[1];
				}
			}
			$namespace = implode('', $parts);
			continue;
		}
		if ($id === T_CLASS || $id === T_INTERFACE || $id === T_TRAIT) {
			$previous = previous_significant_token($tokens, $index);
			if ($id === T_CLASS && ($previous === T_NEW || $previous === T_DOUBLE_COLON)) {
				continue;
			}
			$name = next_named_token($tokens, $index);
			if ($name === null) {
				throw new RuntimeException('named PHP class-like declaration is missing its identifier');
			}
			$qualified = $namespace === '' ? $name : $namespace . '\\' . $name;
			$symbols['class:' . strtolower($qualified)] = $path;
			$await_class_brace = true;
			continue;
		}
		if ($id === T_FUNCTION && count($class_depths) === 0) {
			$name = next_named_token($tokens, $index);
			if ($name !== null) {
				$qualified = $namespace === '' ? $name : $namespace . '\\' . $name;
				$symbols['function:' . strtolower($qualified)] = $path;
			}
		}
	}
	return $symbols;
}

/** @param list<array{0:int, 1:string, 2:int}|string> $tokens */
function previous_significant_token(array $tokens, int $index): ?int
{
	for ($cursor = $index - 1; $cursor >= 0; $cursor--) {
		$token = $tokens[$cursor];
		if (is_string($token)) {
			return null;
		}
		if ($token[0] !== T_WHITESPACE && $token[0] !== T_COMMENT && $token[0] !== T_DOC_COMMENT) {
			return $token[0];
		}
	}
	return null;
}

/** @param list<array{0:int, 1:string, 2:int}|string> $tokens */
function next_named_token(array $tokens, int $index): ?string
{
	$count = count($tokens);
	for ($cursor = $index + 1; $cursor < $count; $cursor++) {
		$token = $tokens[$cursor];
		if (is_string($token)) {
			if ($token === '(') {
				return null;
			}
			continue;
		}
		if ($token[0] === T_STRING) {
			return $token[1];
		}
		if ($token[0] !== T_WHITESPACE && $token[0] !== T_COMMENT && $token[0] !== T_DOC_COMMENT) {
			return null;
		}
	}
	return null;
}

function write_phpstan_autoload(string $temporary_root, string $classmap_path): string
{
	$path = $temporary_root . '/phpstan-autoload.php';
	$source = "<?php\n\ndeclare(strict_types=1);\n\n"
		. '$class_map = require ' . var_export($classmap_path, true) . ";\n"
		. "spl_autoload_register(\n"
		. "\tstatic function ( string \$class_name ) use ( \$class_map ): void {\n"
		. "\t\tif ( isset( \$class_map[ \$class_name ] ) ) {\n"
		. "\t\t\trequire_once \$class_map[ \$class_name ];\n"
		. "\t\t}\n"
		. "\t}\n"
		. ");\n";
	write_private_file($path, $source);
	return $path;
}

function write_autoload_probe(string $temporary_root, string $stage_root, string $classmap_path, bool $has_private_runtime): string
{
	$path = $temporary_root . '/autoload-probe.php';
	$source = "<?php\n\ndeclare(strict_types=1);\n\n"
		. "function add_action( \$hook, \$callback, \$priority, \$accepted_args ) {\n"
		. "\treturn true;\n"
		. "}\n"
		. "function add_filter( \$hook, \$callback, \$priority, \$accepted_args ) {\n"
		. "\treturn true;\n"
		. "}\n"
		. "define( 'ABSPATH', __DIR__ );\n"
		. '$status = require ' . var_export($stage_root . '/includes/autoload.php', true) . ";\n";
	if ($has_private_runtime) {
		$source .= "if ( true !== \$status ) { exit( 10 ); }\n"
			. '$class_map = require ' . var_export($classmap_path, true) . ";\n"
			. "foreach ( array_keys( \$class_map ) as \$class_name ) {\n"
			. "\tif ( ! class_exists( \$class_name ) && ! interface_exists( \$class_name ) && ! trait_exists( \$class_name ) ) { exit( 11 ); }\n"
			. "}\n";
	} else {
		$source .= "if ( 1 !== \$status && true !== \$status ) { exit( 12 ); }\n";
	}
	$source .= "fwrite( STDOUT, \"autoload-ok\\n\" );\n";
	write_private_file($path, $source);
	return $path;
}

function write_private_file(string $path, string $source): void
{
	if (file_put_contents($path, $source, LOCK_EX) === false) {
		throw new RuntimeException('could not write a private PHP quality probe');
	}
	chmod($path, 0600);
}

/** @param list<string> $relative_paths */
function digest_files(string $root, array $relative_paths): string
{
	$context = hash_init('sha256');
	foreach ($relative_paths as $relative) {
		$path = $root . '/' . $relative;
		require_exact_file($path, 'PHP quality policy input');
		hash_update($context, $relative . "\0" . hash_file('sha256', $path) . "\0");
	}
	return hash_final($context);
}

function remove_tree(string $root): void
{
	$system_temporary_root = realpath(sys_get_temp_dir());
	if (!is_string($system_temporary_root)) {
		throw new RuntimeException('could not resolve the system temporary directory');
	}
	$prefix = rtrim($system_temporary_root, DIRECTORY_SEPARATOR) . DIRECTORY_SEPARATOR . 'wordpresshx-php-quality-';
	if (strpos($root, $prefix) !== 0 || !is_dir($root) || is_link($root)) {
		throw new RuntimeException('refusing to remove an unexpected PHP quality path');
	}
	$entries = scandir($root);
	if ($entries === false) {
		throw new RuntimeException('could not inspect the private PHP quality path');
	}
	foreach ($entries as $entry) {
		if ($entry === '.' || $entry === '..') {
			continue;
		}
		$path = $root . DIRECTORY_SEPARATOR . $entry;
		if (is_link($path) || is_file($path)) {
			if (!unlink($path)) {
				throw new RuntimeException('could not remove a private PHP quality file');
			}
		} elseif (is_dir($path)) {
			remove_tree_child($path);
		} else {
			throw new RuntimeException('private PHP quality path changed to a special file');
		}
	}
	if (!rmdir($root)) {
		throw new RuntimeException('could not remove the private PHP quality directory');
	}
}

function remove_tree_child(string $root): void
{
	$entries = scandir($root);
	if ($entries === false) {
		throw new RuntimeException('could not inspect a private PHP quality subdirectory');
	}
	foreach ($entries as $entry) {
		if ($entry === '.' || $entry === '..') {
			continue;
		}
		$path = $root . DIRECTORY_SEPARATOR . $entry;
		if (is_link($path) || is_file($path)) {
			if (!unlink($path)) {
				throw new RuntimeException('could not remove a private PHP quality file');
			}
		} elseif (is_dir($path)) {
			remove_tree_child($path);
		} else {
			throw new RuntimeException('private PHP quality path changed to a special file');
		}
	}
	if (!rmdir($root)) {
		throw new RuntimeException('could not remove a private PHP quality subdirectory');
	}
}
