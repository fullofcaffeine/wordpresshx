package wordpresshx.cli.ownership;

/** A version-locked validator callback run against one immutable captured stage. **/
typedef StageValidator = {
	final validatorId:String;
	final run:(snapshot:StageSnapshot) -> Void;
}
