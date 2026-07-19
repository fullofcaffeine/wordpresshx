package wordpresshx.cli.project;

import wordpresshx.cli.ownership.OwnershipLayout;

typedef ProjectOwnershipPaths = {
	final layout:OwnershipLayout;
	final metadataPath:String;
	final metadataRootId:String;
	final distributionRootId:String;
	final reproducibilityPath:String;
	final archivePath:String;
}
