<?php

declare(strict_types=1);

\add_action( 'wordpresshx_fixture_fail', array( \Fixture\Correlation\FailureCallbacks::class, 'failHook' ), 10, 0 );
\add_action( 'rest_api_init', array( \Fixture\Correlation\FailureCallbacks::class, 'registerRestRoutes' ), 10, 0 );
\add_action( 'init', array( \Fixture\Correlation\FailureCallbacks::class, 'registerBlocks' ), 10, 0 );
