<?php

declare(strict_types=1);

\add_action( 'init', array( \Acme\BooksAdapters\PublicAdapters::class, 'onInit' ), 9, 0 );
\add_filter( 'the_title', array( \Acme\BooksAdapters\PublicAdapters::class, 'filterTitle' ), 12, 2 );
\add_action( 'rest_api_init', array( \Acme\BooksAdapters\PublicAdapters::class, 'registerRestRoutes' ), 10, 0 );
\add_action( 'init', array( \Acme\BooksAdapters\PublicAdapters::class, 'registerBlocks' ), 10, 0 );
