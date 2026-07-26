# WordPressHx G1 PHP review packet

Start with the generated PHP. It is the interface that WordPress, plugin
authors, operations teams, and debuggers actually see. The Haxe and correlation
files explain where that PHP came from; they are not required at runtime.

## 1. Ordinary PHP naming and shape

Review:

- `php/acme-books-adapters/acme-books-adapters.php`
- `php/acme-books-adapters/includes/PublicAdapters.php`
- `php/source-correlation/includes/FailureCallbacks.php`
- `callers/native-adapter-caller.php`

Check namespaces, class and method names, parameter and return declarations,
visibility, callable arrays, by-reference behavior, and whether a PHP developer
can use reflection or call the public exports without a Haxe runtime.

## 2. WordPress conventions

Review:

- `php/acme-books-adapters/acme-books-adapters.php`
- `php/acme-books-adapters/includes/register-adapters.php`
- `callers/probe-adapters.php`
- `evidence/g1.3-wordpress-activation-hook.json`

Check the plugin header, `ABSPATH` guard, root-owned activation hook, local
autoloading, action/filter priorities and accepted argument counts, REST
permission callback, `WP_Error` behavior, block registration, escaping, and
the persisted activation effect.

## 3. Control flow and bootstrap

Follow this sequence:

```text
plugin root -> local autoloader -> activation registration -> bootstrap
            -> adapter registrations -> WordPress calls public adapters
```

Review every file under `php/acme-books-adapters/`. Confirm that load-time work
is obvious, idempotent where required, and free of hidden framework/runtime
indirection.

## 4. Adapters and private boundary

Review:

- `php/source-correlation/includes/FailureCallbacks.php`
- `callers/source-correlation-caller.php`
- `haxe/fixtures/SourceCorrelationCallbacks.hx`
- `evidence/sdk-024-private-php-runtime.json`

The public native adapter is the stable WordPress/PHP boundary. Private
implementation details may sit behind it, but must remain visible in ordinary
PHP frames and must not leak a second public ABI. Check that this distinction
is understandable from the generated code and evidence.

## 5. Errors and native stack frames

Review all files under `traces/`. Each `*.native.stack` file is output from a
real PHP 8.4 container invocation. Each matching `*.correlated.json` preserves
every native line and adds one exact Haxe statement mapping. The private case
deliberately retains an `unmapped-no-anchor` frame rather than guessing.

Check that the original exception class, message, generated PHP file, line,
call sequence, and unmapped frames remain available to ordinary PHP tools.

## 6. Haxe source correlation

Review:

- `debug/source-index.json`
- `debug/includes/FailureCallbacks.php.haxe-map.json`
- `haxe/fixtures/SourceCorrelationCallbacks.hx`
- `traces/*.correlated.json`

Check that mappings are content-bound, use project-relative Haxe paths, point
to the correct statements, and do not replace or falsify native frames. The
production PHP directory intentionally contains no map, source index, or Haxe
source; those belong to the separate debug companion.

## Decision boundary

Classify every finding as `blocking`, `non-blocking`, or `observation`.
Acceptance requires all six categories to be reviewed and every blocking
finding to be resolved against a newly content-addressed packet. Acceptance is
readability/debuggability evidence only: it is not a package publication,
security certification, compatibility promise, or production-support claim.
