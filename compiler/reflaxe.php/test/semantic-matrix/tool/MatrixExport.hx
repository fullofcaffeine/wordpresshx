import reflaxe.php.compiler.PhpSemanticCapabilities;

class MatrixExport {
	static function main():Void {
		final records = PhpSemanticCapabilities.records();
		records.sort((left, right) -> left.id.value() < right.id.value() ? -1 : left.id.value() > right.id.value() ? 1 : 0);
		for (record in records) {
			Sys.println([
				record.id.value(),
				record.category.value(),
				record.state.value(),
				record.evidence,
				record.owner
			].join("\t"));
		}
	}
}
