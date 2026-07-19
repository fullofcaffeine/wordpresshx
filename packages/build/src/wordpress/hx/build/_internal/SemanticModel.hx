package wordpress.hx.build._internal;

#if macro
typedef SourcePoint = {
	final offset:Int;
	final line:Int;
	final column:Int;
}

typedef SourceSpan = {
	final path:String;
	final sourceSha256:String;
	final start:SourcePoint;
	final end:SourcePoint;
	final symbol:String;
}

typedef Projection = {
	final projectionId:String;
	final emitterId:String;
	final artifactKind:String;
}

typedef ModuleNodePayload = {
	final moduleId:String;
	final moduleType:String;
	final displayName:String;
	final version:String;
	final namespace:String;
}

typedef HookNodePayload = {
	final hookName:String;
	final hookType:String;
	final callbackSymbol:String;
	final priority:Int;
	final acceptedArgs:Int;
}

enum DevelopmentServiceKind {
	WordPressService;
	ExternalService;
}

enum DevelopmentReadinessKind {
	HttpReadiness;
	LogReadiness;
	ProcessReadiness;
	TcpReadiness;
}

enum DevelopmentReloadKind {
	FullPageReload;
	NoReload;
}

typedef DevelopmentCommand = {
	final component:String;
	final executable:String;
	final arguments:Array<String>;
}

typedef DevelopmentPort = {
	final preferred:Int;
	final strict:Bool;
}

typedef DevelopmentReadiness = {
	final kind:DevelopmentReadinessKind;
	final path:String;
	final text:String;
	final timeoutMs:Int;
	final intervalMs:Int;
}

typedef DevelopmentRestart = {
	final maxAttempts:Int;
	final backoffMs:Int;
}

typedef DevelopmentUrl = {
	final scheme:String;
	final path:String;
}

typedef DevelopmentServiceData = {
	final serviceId:String;
	final serviceKind:DevelopmentServiceKind;
	final dependsOn:Array<String>;
	final workingDirectory:String;
	final command:Null<DevelopmentCommand>;
	final environment:Array<String>;
	final port:DevelopmentPort;
	final readiness:DevelopmentReadiness;
	final restart:DevelopmentRestart;
	final url:DevelopmentUrl;
	final reload:DevelopmentReloadKind;
}

enum SemanticPayload {
	ModulePayload(value:ModuleNodePayload);
	HookPayload(value:HookNodePayload);
	DevelopmentPayload(value:DevelopmentServiceData);
}

typedef SemanticNode = {
	final id:String;
	final kind:String;
	final schemaId:String;
	final source:SourceSpan;
	final relatedSources:Array<SourceSpan>;
	final dependsOn:Array<String>;
	final profileCapabilities:Array<String>;
	final projections:Array<Projection>;
	final payload:SemanticPayload;
}

typedef ToolRecord = {
	final id:String;
	final version:String;
	final identity:String;
	final lockEntrySha256:String;
}

typedef InputFileRecord = {
	final path:String;
	final sha256:String;
	final byteLength:Int;
	final role:String;
}

typedef ResourceRecord = {
	final id:String;
	final path:String;
}

typedef EnvironmentRecord = {
	final name:String;
	final classification:String;
	final required:Bool;
	final source:String;
	final valueSha256:String;
}

typedef InputProjectRecord = {
	final id:String;
	final version:String;
	final configPath:String;
}

typedef InputProfileRecord = {
	final id:String;
	final catalogRevision:String;
	final catalogSha256:String;
}

typedef CollectorInputMaterial = {
	final schema:String;
	final canonicalization:String;
	final fingerprintAlgorithm:String;
	final project:InputProjectRecord;
	final profile:InputProfileRecord;
	final files:Array<InputFileRecord>;
	final resources:Array<ResourceRecord>;
	final environment:Array<EnvironmentRecord>;
	final tools:Array<ToolRecord>;
}

typedef CollectorInputs = {
	final material:CollectorInputMaterial;
	final fingerprint:String;
	final planDigest:String;
}

typedef GeneratorRecord = {
	final sdkVersion:String;
	final collectorId:String;
	final collectorVersion:String;
	final collectorSourceSha256:String;
	final toolchainSha256:String;
}

typedef PlanProfileRecord = {
	final profileId:String;
	final catalogRevision:String;
	final catalogSha256:String;
}

typedef PlanProjectRecord = {
	final projectId:String;
	final projectVersion:String;
	final sourceTreeSha256:String;
}

typedef NodeSchemaRecord = {
	final schemaId:String;
	final kind:String;
	final version:Int;
	final authority:String;
	final extensionId:Null<String>;
	final schemaSha256:String;
	final consumerEmitters:Array<String>;
}

typedef SemanticPlanRecord = {
	final schema:String;
	final canonicalization:String;
	final planDigestAlgorithm:String;
	final planDigest:Null<String>;
	final generator:GeneratorRecord;
	final profile:PlanProfileRecord;
	final project:PlanProjectRecord;
	final nodeSchemas:Array<NodeSchemaRecord>;
	final nodes:Array<SemanticNode>;
}

typedef FileDigestRecord = {
	final path:String;
	final sha256:String;
}
#end
