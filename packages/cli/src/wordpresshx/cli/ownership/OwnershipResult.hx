package wordpresshx.cli.ownership;

/** Stable transaction outcomes suitable for CLI events and tests. **/
enum abstract OwnershipResult(String) to String {
	var Published = "published";
	var PublishedRecovered = "published-recovered";
	var NoOp = "no-op";
	var Finalized = "finalized";
	var RolledBack = "rolled-back";
	var NothingToRecover = "nothing-to-recover";
}
