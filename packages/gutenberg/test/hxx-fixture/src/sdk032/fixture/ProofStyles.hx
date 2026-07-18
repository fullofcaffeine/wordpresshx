package sdk032.fixture;

/** Visual fixture authored with the Haxe component; no handwritten CSS artifact is shipped. */
class ProofStyles {
	public static final css = '
@layer reset, proof;
@layer reset {
  *, *::before, *::after { box-sizing: border-box; }
  html { color-scheme: light; }
  body { margin: 0; }
  button { font: inherit; }
}
@layer proof {
  .proof {
    --paper: #f2f0e8;
    --paper-deep: #e8e3d7;
    --ink: #10283e;
    --ink-soft: #52606c;
    --rule: rgba(16, 40, 62, .2);
    --red: #b93421;
    --cyan: #2d9dad;
    --cyan-ink: #167383;
    min-height: 100vh;
    padding: clamp(18px, 3vw, 46px);
    color: var(--ink);
    background:
      linear-gradient(rgba(16, 40, 62, .028) 1px, transparent 1px),
      linear-gradient(90deg, rgba(16, 40, 62, .028) 1px, transparent 1px),
      var(--paper-deep);
    background-size: 24px 24px;
    font-family: ui-monospace, "SFMono-Regular", "Cascadia Code", monospace;
    position: relative;
    overflow: hidden;
  }
  .proof::before {
    content: "";
    position: fixed;
    inset: 0;
    pointer-events: none;
    opacity: .18;
    background-image: radial-gradient(rgba(16, 40, 62, .3) .45px, transparent .6px);
    background-size: 5px 5px;
    mix-blend-mode: multiply;
  }
  .proof__frame {
    width: 100%;
    max-width: 1180px;
    min-width: 0;
    margin: 0 auto;
    border: 1px solid var(--ink);
    background: var(--paper);
    box-shadow: 10px 10px 0 rgba(16, 40, 62, .11);
    position: relative;
  }
  .proof__frame::before, .proof__frame::after {
    content: "";
    position: absolute;
    top: -7px;
    width: 38px;
    border-top: 2px solid var(--red);
  }
  .proof__frame::before { left: -20px; transform: rotate(-1deg); }
  .proof__frame::after { right: -20px; transform: rotate(1deg); }
  .proof__registration span {
    position: fixed;
    color: var(--red);
    font-size: 20px;
    line-height: 1;
  }
  .proof__registration span:nth-child(1) { top: 10px; left: 10px; }
  .proof__registration span:nth-child(2) { top: 10px; right: 10px; }
  .proof__registration span:nth-child(3) { bottom: 10px; left: 10px; }
  .proof__registration span:nth-child(4) { right: 10px; bottom: 10px; }
  .proof__masthead { padding: clamp(22px, 4vw, 52px); border-bottom: 1px solid var(--ink); }
  .proof__eyebrow, .proof__footer, .proof__sheet-foot {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 16px;
    font-size: 10px;
    letter-spacing: .13em;
  }
  .proof__eyebrow { padding-bottom: 22px; border-bottom: 1px solid var(--rule); }
  .proof__slug { padding: 6px 8px; color: var(--paper); background: var(--ink); letter-spacing: .06em; }
  .proof__edition { color: var(--red); }
  .proof__headline { display: grid; grid-template-columns: minmax(0, 1.4fr) minmax(230px, .6fr); gap: 48px; align-items: end; padding-top: 34px; }
  .proof__headline > *, .proof__workspace > *, .proof__sheet-head > *, .proof__sheet-foot > *, .proof__check-copy { min-width: 0; }
  .proof__overline, .proof__folio { margin: 0 0 14px; color: var(--red); font-size: 10px; font-weight: 700; letter-spacing: .14em; text-transform: uppercase; }
  .proof h1 {
    margin: 0;
    max-width: 760px;
    font-family: "Iowan Old Style", "Palatino Linotype", Georgia, serif;
    font-size: clamp(58px, 10vw, 126px);
    font-weight: 500;
    letter-spacing: -.075em;
    line-height: .72;
  }
  .proof h1 span { color: var(--ink); -webkit-text-stroke: 1px var(--paper); text-shadow: 2px 0 var(--red), -2px 0 var(--cyan); }
  .proof__lede { margin: 0; padding-left: 20px; border-left: 3px double var(--ink); color: var(--ink-soft); font-family: "Iowan Old Style", Georgia, serif; font-size: clamp(17px, 2vw, 22px); line-height: 1.45; }
  .proof__workspace { display: grid; grid-template-columns: minmax(0, 3fr) minmax(250px, 1fr); }
  .proof__sheet { padding: clamp(24px, 4vw, 48px); border-right: 1px solid var(--ink); }
  .proof__sheet-head { display: flex; align-items: flex-start; justify-content: space-between; gap: 24px; }
  .proof h2 { margin: 0; font-family: "Iowan Old Style", Georgia, serif; font-size: clamp(29px, 4vw, 46px); font-weight: 500; letter-spacing: -.035em; }
  .proof__stamp { padding: 10px 12px 8px; border: 2px solid var(--red); color: var(--red); font-size: 11px; font-weight: 800; letter-spacing: .12em; transform: rotate(3deg); transition: transform 180ms ease, color 180ms ease, border-color 180ms ease; }
  .proof__stamp--accepted { color: var(--cyan-ink); border-color: var(--cyan-ink); transform: rotate(-2deg) scale(1.04); }
  .proof__rule { display: grid; grid-template-columns: 1fr auto 1fr; gap: 14px; align-items: center; margin: 30px 0 12px; color: var(--ink-soft); font-size: 9px; letter-spacing: .12em; }
  .proof__rule span { height: 1px; background: var(--rule); }
  .proof__checks { margin: 0; padding: 0; border-top: 1px solid var(--ink); list-style: none; }
  .proof__check { border-bottom: 1px solid var(--ink); }
  .proof__check-trigger { width: 100%; padding: 17px 10px; border: 0; color: inherit; background: transparent; cursor: pointer; display: grid; grid-template-columns: 26px 1fr auto; gap: 12px; align-items: center; text-align: left; }
  .proof__check-trigger:hover { background: rgba(45, 157, 173, .08); }
  .proof__check-trigger:focus-visible, .proof__action:focus-visible { outline: 3px solid var(--cyan-ink); outline-offset: 3px; }
  .proof__check--selected .proof__check-trigger { background: var(--ink); color: var(--paper); }
  .proof__check-mark { color: var(--red); font-size: 18px; }
  .proof__check-copy { display: grid; gap: 4px; }
  .proof__check-copy strong { font-size: 13px; letter-spacing: .02em; }
  .proof__check-copy span { color: var(--ink-soft); font-family: "Iowan Old Style", Georgia, serif; font-size: 15px; overflow-wrap: anywhere; }
  .proof__check--selected .proof__check-copy span { color: rgba(242, 240, 232, .7); }
  .proof__check-code { padding: 5px 6px; border: 1px solid currentColor; font-size: 9px; font-weight: 800; }
  .proof__result { min-height: 76px; margin-top: 22px; }
  .proof__notice { margin: 0 !important; border-radius: 0 !important; box-shadow: none !important; }
  .proof__sheet-foot { margin-top: 22px; padding-top: 22px; border-top: 1px solid var(--rule); }
  .proof__tags { max-width: 260px; color: var(--ink-soft); font-size: 9px; line-height: 1.5; letter-spacing: .1em; }
  .proof__action { min-height: 44px; border-radius: 0 !important; font-weight: 700 !important; letter-spacing: .02em; }
  .proof__notes { padding: clamp(24px, 3vw, 38px); background: rgba(16, 40, 62, .035); }
  .proof__notes > h2 { margin-bottom: 28px; font-size: 31px; }
  .proof__metric { display: grid; grid-template-columns: 66px 1fr; gap: 15px; align-items: center; padding: 15px 0; border-top: 1px solid var(--rule); }
  .proof__metric strong { color: var(--red); font-family: "Iowan Old Style", Georgia, serif; font-size: 46px; font-weight: 400; line-height: .9; }
  .proof__metric span { color: var(--ink-soft); font-size: 10px; letter-spacing: .08em; text-transform: uppercase; }
  .proof__annotation { margin: 30px -12px 0; padding: 20px; color: var(--paper); background: var(--ink); transform: rotate(-1deg); }
  .proof__annotation > span, .proof__context span { display: block; margin-bottom: 8px; font-size: 9px; letter-spacing: .14em; }
  .proof__annotation > span { color: var(--cyan); }
  .proof__context span { color: var(--cyan-ink); }
  .proof__annotation > strong { font-size: 12px; letter-spacing: .07em; }
  .proof__annotation p { margin: 16px 0 0; color: rgba(242, 240, 232, .72); font-family: "Iowan Old Style", Georgia, serif; font-size: 15px; line-height: 1.4; }
  .proof__context { margin-top: 30px; padding-top: 18px; border-top: 1px solid var(--rule); }
  .proof__context strong { font-size: 10px; font-weight: 600; }
  .proof__footer { padding: 14px clamp(22px, 4vw, 52px); border-top: 1px solid var(--ink); color: var(--ink-soft); font-size: 9px; }
  @media (max-width: 820px) {
    .proof { padding: 12px; }
    .proof__headline { grid-template-columns: 1fr; gap: 28px; }
    .proof h1 { font-size: clamp(55px, 17vw, 92px); }
    .proof__workspace { grid-template-columns: 1fr; }
    .proof__sheet { border-right: 0; border-bottom: 1px solid var(--ink); }
    .proof__notes { display: grid; grid-template-columns: repeat(3, 1fr); gap: 12px; }
    .proof__notes > .proof__folio, .proof__notes > h2, .proof__annotation, .proof__context { grid-column: 1 / -1; }
    .proof__metric { grid-template-columns: 1fr; }
  }
  @media (max-width: 520px) {
    .proof__edition { display: none; }
    .proof__eyebrow { gap: 10px; font-size: 8px; letter-spacing: .08em; }
    .proof__masthead, .proof__sheet, .proof__notes { padding: 20px; }
    .proof h1 { font-size: clamp(46px, 14.5vw, 64px); letter-spacing: -.065em; line-height: .78; }
    .proof__lede { padding-left: 15px; overflow-wrap: anywhere; }
    .proof__sheet-head, .proof__sheet-foot { align-items: stretch; flex-direction: column; }
    .proof__stamp { align-self: flex-start; }
    .proof__action { width: 100%; justify-content: center; }
    .proof__notes { grid-template-columns: 1fr; }
    .proof__metric { grid-template-columns: 56px 1fr; }
    .proof__footer { align-items: flex-start; flex-direction: column; }
  }
  @media (prefers-reduced-motion: reduce) {
    *, *::before, *::after { scroll-behavior: auto !important; transition-duration: .01ms !important; animation-duration: .01ms !important; animation-iteration-count: 1 !important; }
  }
}
';
}
