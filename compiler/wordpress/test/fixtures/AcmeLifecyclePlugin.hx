package fixtures;

import reflaxe.php.ir.PhpExpr;
import reflaxe.php.ir.PhpQualifiedName;
import reflaxe.php.ir.PhpSourceRange;
import reflaxe.php.ir.PhpStmt;
import wordpress.hx.compiler.php.profile.PluginBootstrapPlan;
import wordpress.hx.compiler.php.profile.PluginHeader;
import wordpress.hx.compiler.php.profile.WordPressPluginInstallKind;
import wordpress.hx.compiler.php.profile.WordPressPluginLifecyclePlan;
import wordpress.hx.compiler.php.profile.WordPressPluginUpgradeStep;
import wordpress.hx.compiler.php.profile.WordPressUninstallPolicy;

/** Independently authored SDK-051 lifecycle and retry fixture. */
class AcmeLifecyclePlugin {
	public static function standardV1():WordPressPluginLifecyclePlan {
		return standard(1);
	}

	public static function standardV3():WordPressPluginLifecyclePlan {
		return standard(3);
	}

	public static function mustUseV3():WordPressPluginLifecyclePlan {
		return new WordPressPluginLifecyclePlan(plugin("acme-lifecycle-mu", "Acme Lifecycle MU", "Acme\\LifecycleMu", "3.0.0"), MustUsePlugin,
			"acme_lifecycle_mu_schema_version", 3, steps("acme_lifecycle_mu", false), RetainPluginData, []);
	}

	static function standard(target:Int):WordPressPluginLifecyclePlan {
		final allSteps = steps("acme_lifecycle", true);
		return new WordPressPluginLifecyclePlan(plugin("acme-lifecycle", "Acme Lifecycle", "Acme\\Lifecycle", target + ".0.0"), StandardPlugin,
			"acme_lifecycle_schema_version", target, allSteps.slice(0, target), DeleteDeclaredPluginData, [
				"acme_lifecycle_migration_1_runs",
				"acme_lifecycle_migration_2_runs",
				"acme_lifecycle_migration_3_runs",
				"acme_lifecycle_schema_version"
			]);
	}

	static function steps(prefix:String, failThird:Bool):Array<WordPressPluginUpgradeStep> {
		return [
			new WordPressPluginUpgradeStep(0, 1, [increment(prefix + "_migration_1_runs")]),
			new WordPressPluginUpgradeStep(1, 2, [increment(prefix + "_migration_2_runs")]),
			new WordPressPluginUpgradeStep(2, 3, failThird ? [
				PhpIf(PhpFunctionCall("defined", [PhpString("ACME_LIFECYCLE_FAIL_V3")]), [
					PhpThrow(PhpNew("\\RuntimeException", [PhpString("intentional lifecycle migration failure at schema 3")]))
				]),
				increment(prefix + "_migration_3_runs")
			] : [increment(prefix + "_migration_3_runs")])
		];
	}

	static function increment(option:String):PhpStmt {
		return PhpExprStmt(PhpFunctionCall("\\update_option", [
			PhpString(option),
			PhpBinop("+", PhpCastInt(PhpFunctionCall("\\get_option", [PhpString(option), PhpInt(0)])), PhpInt(1)),
			PhpBool(false)
		]));
	}

	static function plugin(slug:String, name:String, namespace:String, version:String):PluginBootstrapPlan {
		return new PluginBootstrapPlan(slug,
			new PluginHeader(name, "Typed SDK-051 lifecycle fixture.", version, "7.0", "7.4", "WordPressHx SDK fixture",
				"LicenseRef-WordPressHx-Review-Pending", slug),
			PhpQualifiedName.relative(namespace), PhpSourceRange.at("compiler/wordpress/test/fixtures/AcmeLifecyclePlugin.hx", 1, 1, 1, 2));
	}
}
