package reflaxe.php.ir;

enum PhpDeclaration {
	PhpFunctionDeclaration(declaration:PhpFunction);
	PhpClassDeclaration(declaration:PhpClass);
}
