package reflaxe.php.ir;

/** PHP 7.4-compatible signature types admitted by the generic IR. **/
enum PhpType {
	PhpNamedType(name:PhpQualifiedName);
	PhpArrayType;
	PhpBoolType;
	PhpCallableType;
	PhpFloatType;
	PhpIntType;
	PhpIterableType;
	PhpObjectType;
	PhpStringType;
	PhpVoidType;
	PhpNullableType(inner:PhpType);
}
