package wordpress.hx.contracts;

import wordpress.hx.contracts.schema.SchemaDocument;

interface ContractCodec<T> {
	public function schema():SchemaDocument;
	public function encode(value:T):WireValue;
	public function decode(value:WireValue):DecodeResult<T>;
}
