package reflaxe.php.map;

import reflaxe.php.ir.PhpStableId;

/** Caller-owned public format identity plus immutable compiler/build provenance. **/
class PhpRangeMapConfig {
	public final format:String;
	public final generatorId:String;
	public final generatorVersion:String;
	public final generatorSourceSha256:String;
	public final buildInputsSha256:String;

	public function new(format:String, generatorId:String, generatorVersion:String, generatorSourceSha256:String, buildInputsSha256:String) {
		this.format = PhpStableId.validate(format, "range-map format");
		this.generatorId = PhpStableId.validate(generatorId, "range-map generator ID");
		if (generatorVersion == null || generatorVersion.length == 0 || generatorVersion.length > 512 || generatorVersion.indexOf("\x00") != -1) {
			throw "Invalid PHP range-map generator version";
		}
		this.generatorVersion = generatorVersion;
		this.generatorSourceSha256 = validateSha256(generatorSourceSha256, "generator source");
		this.buildInputsSha256 = validateSha256(buildInputsSha256, "build inputs");
	}

	static function validateSha256(value:String, label:String):String {
		if (value == null || !~/^[0-9a-f]{64}$/.match(value)) {
			throw "Invalid PHP range-map " + label + " SHA-256";
		}
		return value;
	}
}
