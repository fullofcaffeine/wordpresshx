package wordpress.hx.core.profile;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#end

class ProfileGate {
	public static macro function requireCapability(capabilityId:ExprOf<String>, availableIn:ExprOf<Array<String>>):Expr {
		final id = switch capabilityId.expr {
			case EConst(CString(value, _)): value;
			case _: Context.error("capability ID must be a string literal", capabilityId.pos);
		};
		final profiles = switch availableIn.expr {
			case EArrayDecl(values): values.map(expression -> switch expression.expr {
					case EConst(CString(value, _)): value;
					case _: Context.error("profile ID must be a string literal", expression.pos);
				});
			case _: Context.error("profile availability must be a literal array", availableIn.pos);
		};
		final selected = Context.definedValue("wordpress_hx_profile");
		if (selected == null || selected.length == 0) {
			Context.error('WPX1200: ${id} requires explicit -D wordpress_hx_profile=<exact-profile>.', Context.currentPos());
		}
		if (profiles.indexOf(selected) == -1) {
			Context.error('WPX1204: ${id} is not available in profile ${selected}. Available in ${profiles.join(", ")} only.', Context.currentPos());
		}
		return macro null;
	}
}
