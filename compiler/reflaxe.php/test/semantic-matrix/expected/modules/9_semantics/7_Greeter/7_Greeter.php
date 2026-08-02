<?php

declare(strict_types=1);

class Hx_9_semantics_7_Greeter {
	private string $prefix;

	public function __construct(string $prefix) {
		$this->prefix = $prefix;
	}

	public function render(string $value): string {
		return $this->prefix . $value;
	}
}
