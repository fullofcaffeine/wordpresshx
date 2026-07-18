package wordpresshx.cli.ownership;

/** A version-locked validator callback run against the complete caller stage. **/
typedef StageValidator = {
	final validatorId:String;
	final run:(stageRoot:String) -> Void;
}
