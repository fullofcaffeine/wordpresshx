package sdk035.fixture;

import wordpress.hx.gutenberg.browser.BrowserNode;
import wordpress.hx.gutenberg.react.DomTypes.HtmlButtonElement;
import wordpress.hx.gutenberg.react.Hooks.useState;
import wordpress.hx.gutenberg.react.ReactTypes.ReactMouseEvent;

typedef DifferentialSummary = {
	final count:Int;
	final total:Int;
	final labels:Array<String>;
}

typedef CounterProps = {
	final initial:Int;
	final step:Int;
	final label:String;
}

/**
 * Same-source semantic contract for the strict TSX and classic Genes lanes.
 *
 * The facade deliberately combines an ordinary data/function API with one
 * small hook-driven React component. SDK-035 compares observable behavior;
 * generated spelling is only classified as an expected target difference.
 */
@:build(wordpress.hx.gutenberg.browser.BrowserExport.build("wordpresshx.sdk035.differential-api", []))
class DifferentialApi {
	public static function summarize(prefix:String, values:Array<Int>):DifferentialSummary {
		var total = 0;
		final labels:Array<String> = [];
		for (value in values) {
			total += value;
			labels.push('${prefix}-${value}');
		}
		return {
			count: values.length,
			total: total,
			labels: labels
		};
	}

	public static function describe(label:String, summary:DifferentialSummary):String {
		return '${label}:${summary.count}:${summary.total}:${summary.labels.join("|")}';
	}

	public static function Counter(props:CounterProps):BrowserNode {
		final countState = useState(props.initial);
		final count = countState.value;
		return <section class="differential-counter" data-state={Std.string(count)} aria-label={props.label}>
			<span class="differential-counter__label">{props.label}</span>
			<span class="differential-counter__value" aria-live="polite">{count}</span>
			<button
				type="button"
				onClick={(event:ReactMouseEvent<HtmlButtonElement>) -> {
					event.preventDefault();
					countState.set(count + props.step);
				}}
			>{'Add ${props.step}'}</button>
		</section>;
	}
}
