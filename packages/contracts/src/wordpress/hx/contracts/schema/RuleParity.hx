package wordpress.hx.contracts.schema;

enum abstract RuleParity(String) to String {
	var Exact = "exact";
	var DocumentedNativeRelation = "documented-native-relation";
}
