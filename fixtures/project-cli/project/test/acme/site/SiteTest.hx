package acme.site;

class SiteTest {
	public static function assertIdentity():Void {
		if (Site.projectId != "acme-observatory") {
			throw "unexpected project identity";
		}
	}
}
