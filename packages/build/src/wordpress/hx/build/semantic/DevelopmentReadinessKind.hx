package wordpress.hx.build.semantic;

/** IDE-visible readiness strategies accepted by typed development services. */
enum abstract DevelopmentReadinessKind(String) {
	final Http = "http";
	final Log = "log";
	final Process = "process";
	final Tcp = "tcp";
}
