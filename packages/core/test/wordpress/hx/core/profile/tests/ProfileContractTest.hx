package wordpress.hx.core.profile.tests;

import wordpress.hx.core.profile.AdministrativeResult;
import wordpress.hx.core.profile.ApiClassification;
import wordpress.hx.core.profile.CapabilityId;
import wordpress.hx.core.profile.CatalogDigest;
import wordpress.hx.core.profile.CatalogRevision;
import wordpress.hx.core.profile.CompileTimeCapability;
import wordpress.hx.core.profile.EvidenceStatus;
import wordpress.hx.core.profile.ProfileContractError;
import wordpress.hx.core.profile.ProfileId;
import wordpress.hx.core.profile.RuntimeCapability;
import wordpress.hx.core.profile.RuntimeRequestScope;

class ProfileContractTest {
	private static final DIGEST = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";

	static function main():Void {
		final wp70 = ProfileId.parse("wp70-release");
		final forward = ProfileId.parse("gutenberg-forward-23.4");
		assertEquals("wp70-release/catalog-v1", CatalogRevision.parse(wp70, "wp70-release/catalog-v1").toString());
		assertEquals("public", ApiClassification.parse("public"));
		assertEquals("experimental", ApiClassification.parse("experimental"));
		assertEquals("withdrawn", AdministrativeResult.parse("withdrawn"));
		assertTrue(EvidenceStatus.Inventoried.canPromoteTo(EvidenceStatus.Typed));
		assertTrue(!EvidenceStatus.Inventoried.canPromoteTo(EvidenceStatus.Generated));
		expectError(() -> ApiClassification.parse("stable"), "unknown classification");
		expectError(() -> EvidenceStatus.parse("supported"), "unknown evidence status");
		expectError(() -> CatalogRevision.parse(wp70, "gutenberg-forward-23.4/catalog-v1"), "cross-profile catalog revision");

		final availability = [forward];
		final contentTypes = new CompileTimeCapability(CapabilityId.parse("gutenberg.package.@wordpress/content-types"), CatalogDigest.parse(DIGEST),
			availability);
		availability.push(wp70);
		assertTrue(contentTypes.isAvailableIn(forward));
		assertTrue(!contentTypes.isAvailableIn(wp70));
		contentTypes.require(forward, "ProfileContractTest.hx:1");
		expectError(() -> contentTypes.require(wp70, "ProfileContractTest.hx:2"), "forward capability under wp70");
		final manifest = contentTypes.toManifestValue();
		assertEquals(1, manifest.availableIn.length);
		assertEquals("gutenberg-forward-23.4", manifest.availableIn[0]);

		final scope = RuntimeRequestScope.begin();
		final runtime = RuntimeCapability.available(scope, 42);
		assertEquals(84, runtime.fold(scope, value -> value * 2, _ -> 0));
		final otherScope = RuntimeRequestScope.begin();
		expectError(() -> runtime.fold(otherScope, value -> value, _ -> 0), "cross-request runtime token");
		otherScope.close();
		scope.close();
		expectError(() -> runtime.fold(scope, value -> value, _ -> 0), "closed request runtime token");

		Sys.println("wordpress-hx-core profile contract tests passed");
	}

	private static function assertTrue(value:Bool):Void {
		if (!value) {
			throw new ProfileContractError("assertion failed");
		}
	}

	private static function assertEquals<T>(expected:T, actual:T):Void {
		if (expected != actual) {
			throw new ProfileContractError('expected ${expected}, found ${actual}');
		}
	}

	private static function expectError(run:Void->Void, label:String):Void {
		try {
			run();
		} catch (_:ProfileContractError) {
			return;
		}
		throw new ProfileContractError('negative fixture did not fail: ${label}');
	}
}
