package sdk032.fixture;

import wordpress.hx.gutenberg.browser.BrowserNode;
import wordpress.hx.gutenberg.components.Button;
import wordpress.hx.gutenberg.components.ButtonProps.ButtonVariant;
import wordpress.hx.gutenberg.components.Notice;
import wordpress.hx.gutenberg.components.NoticeProps.NoticePoliteness;
import wordpress.hx.gutenberg.components.NoticeProps.NoticeStatus;
import wordpress.hx.gutenberg.react.DomTypes.HtmlButtonElement;
import wordpress.hx.gutenberg.react.Hooks.createContext;
import wordpress.hx.gutenberg.react.Hooks.useContext;
import wordpress.hx.gutenberg.react.Hooks.useEffect;
import wordpress.hx.gutenberg.react.Hooks.useRef;
import wordpress.hx.gutenberg.react.Hooks.useState;
import wordpress.hx.gutenberg.react.ReactTypes.ReactContext;
import wordpress.hx.gutenberg.react.ReactTypes.ReactKeyboardEvent;
import wordpress.hx.gutenberg.react.ReactTypes.ReactKey;
import wordpress.hx.gutenberg.react.ReactTypes.ReactMouseEvent;
import wordpress.hx.gutenberg.react.ReactTypes.ReactNode;

class Main {
	private static final proofContext:ReactContext<String> = createContext("wp70-release / local proof");

	public static function main():Void {
		// The verification harness mounts `App` as a real React component.
	}

	@:keep
	public static function App():BrowserNode {
		final acceptedState = useState(false);
		final accepted = acceptedState.value;
		final selectedState = useState("typed-markup");
		final selected = selectedState.value;
		final noticeStatus:NoticeStatus = accepted ? NoticeStatus.Success : NoticeStatus.Info;
		final buttonVariant:ButtonVariant = accepted ? ButtonVariant.Secondary : ButtonVariant.Primary;
		final actionRef = useRef((null : Null<HtmlButtonElement>));
		final checks:Array<ProofCheck> = [
			{
				id: "typed-markup",
				label: "Typed markup",
				detail: "HXX is checked before JSX exists."
			},
			{
				id: "gutenberg-runtime",
				label: "Gutenberg runtime",
				detail: "Exact-profile components, ordinary React."
			},
			{
				id: "source-map",
				label: "Source fidelity",
				detail: "Generated TSX points home to Haxe."
			}
		];
		final proofTags:Array<ReactNode> = ["HXX  ·  ", "REACT 18  ·  ", "WP 7.0"];
		final actionDefaults:{
			className:String,
			ref:wordpress.hx.gutenberg.react.ReactTypes.ReactRefObject<HtmlButtonElement>
		} = {
			className: "proof__action",
			ref: actionRef
		};

		useEffect(() -> {
			final button = actionRef.current;
			if (button != null) {
				button.setAttribute("data-ref-ready", "true");
			}
		}, []);

		final accept = (event:ReactMouseEvent<HtmlButtonElement>) -> {
			event.preventDefault();
			acceptedState.set(!accepted);
		};
		final acceptFromKeyboard = (event:ReactKeyboardEvent<HtmlButtonElement>) -> {
			if (event.key == "Enter" || event.key == " ") {
				final button = actionRef.current;
				if (button != null) {
					button.setAttribute("data-key-seen", event.key == " " ? "Space" : event.key);
				}
			}
		};
		final selectCheck = (id:String) -> {
			selectedState.set(id);
		};

		return <main class="proof" data-state={accepted ? "accepted" : "review"} aria-labelledby="proof-title">
			<style>{ProofStyles.css}</style>
			<div class="proof__registration" aria-hidden><span>+</span><span>+</span><span>+</span><span>+</span></div>
			<div class="proof__frame">
				<header class="proof__masthead">
					<div class="proof__eyebrow">
						<span class="proof__slug">WP/HX</span>
						<span>COMPILER PROOF № 032</span>
						<span class="proof__edition">17 JUL 2026</span>
					</div>
					<div class="proof__headline">
						<div>
							<p class="proof__overline">A registration desk for browser markup</p>
							<h1 id="proof-title">Markup,<br/><span>under proof.</span></h1>
						</div>
						<p class="proof__lede">A Haxe-authored React surface, checked against an exact WordPress profile before a single component reaches the browser.</p>
					</div>
				</header>

				<section class="proof__workspace" aria-label="Compiler registration proof">
					<article class="proof__sheet" aria-labelledby="sheet-title">
						<header class="proof__sheet-head">
							<div>
								<p class="proof__folio">SHEET 01 / LIVE SPECIMEN</p>
								<h2 id="sheet-title">Inspect the translation</h2>
							</div>
							<span class={accepted ? "proof__stamp proof__stamp--accepted" : "proof__stamp"}>{accepted ? "ACCEPTED" : "IN REVIEW"}</span>
						</header>

						<div class="proof__rule"><span></span><strong>03 CHECKS</strong><span></span></div>
						<ul class="proof__checks" aria-label="Compiler checks">
							<for {check in checks}>
								<Main.ProofCheckRow key={check.id} check={check} selected={check.id == selected} onSelect={selectCheck} />
							</for>
						</ul>

						<div class="proof__result" id="proof-result" aria-live="polite" aria-atomic>
							<Notice
								className="proof__notice"
								isDismissible={false}
								politeness={NoticePoliteness.Polite}
								status={noticeStatus}
							>
								<>
									<strong>{accepted ? "Proof registered." : "Ready for registration."}</strong>
									<span>{accepted ? " The runtime contract remained intact." : " Select a check, then accept the specimen."}</span>
								</>
							</Notice>
						</div>

						<footer class="proof__sheet-foot">
							<div class="proof__tags" role="group" aria-label="Build targets">{...proofTags}</div>
							<Button
								{...actionDefaults}
								ariaControls="proof-result"
								ariaExpanded={accepted}
								onClick={accept}
								onKeyDown={acceptFromKeyboard}
								variant={buttonVariant}
							>
								<if {accepted}>Reopen proof<else>Accept this proof</if>
							</Button>
						</footer>
					</article>

					<aside class="proof__notes" role="region" aria-labelledby="notes-title">
						<p class="proof__folio">MARGIN NOTES / EXACT PROFILE</p>
						<h2 id="notes-title">What survived?</h2>
						<div class="proof__metric"><strong>0</strong><span>runtime HXX parsers</span></div>
						<div class="proof__metric"><strong>2</strong><span>WordPress components</span></div>
						<div class="proof__metric"><strong>5</strong><span>typed React hooks</span></div>
						<div class="proof__annotation">
							<span>SELECTED CHECK</span>
							<strong>{selected.toUpperCase().split("-").join(" ")}</strong>
							<p>Every public edge stays readable in generated TSX. Escape hatches remain visible and deliberate.</p>
						</div>
						<div class="proof__context" data-context={useContext(proofContext)}>
							<span>CONTEXT</span>
							<strong>{useContext(proofContext)}</strong>
						</div>
					</aside>
				</section>

				<footer class="proof__footer">
					<span>WORDPRESSHX / BROWSER SURFACE</span>
					<span>HAXE IN → TYPED TSX OUT</span>
				</footer>
			</div>
		</main>;
	}

	private static function ProofCheckRow(props:ProofCheckProps):BrowserNode {
		final context = useContext(proofContext);
		final className = props.selected ? "proof__check proof__check--selected" : "proof__check";
		final triggerDefaults:{className:String} = {
			className: "proof__check-trigger"
		};
		return <li class={className} key={props.check.id} data-state={props.selected ? "selected" : "idle"} data-context={context}>
			<button
				{...triggerDefaults}
				ariaLabel={'Inspect ${props.check.label}'}
				type="button"
				onClick={(event:ReactMouseEvent<HtmlButtonElement>) -> {
					event.preventDefault();
					props.onSelect(props.check.id);
				}}
			>
				<span class="proof__check-mark" aria-hidden>{props.selected ? "●" : "○"}</span>
				<span class="proof__check-copy"><strong>{props.check.label}</strong><span>{props.check.detail}</span></span>
				<span class="proof__check-code">{props.check.id == "typed-markup" ? "HX" : props.check.id == "gutenberg-runtime" ? "WP" : "TS"}</span>
			</button>
		</li>;
	}
}

private typedef ProofCheck = {
	final id:String;
	final label:String;
	final detail:String;
}

private typedef ProofCheckProps = {
	final check:ProofCheck;
	@:optional final key:ReactKey;
	final selected:Bool;
	final onSelect:String->Void;
}
