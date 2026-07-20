package sdk063.fixture;

class EditorStyles {
	public static final css = '
.wphx-readiness {
  --ink: #102c3e;
  --paper: #f4f0e6;
  --signal: #bd2d1b;
  --cool: #56c8cf;
  background: var(--paper);
  border-block: 1px solid var(--ink);
  color: var(--ink);
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
}
.wphx-readiness__header { padding: 24px 20px 20px; border-bottom: 1px solid var(--ink); }
.wphx-readiness__eyebrow { display: block; color: var(--signal); font-size: 10px; font-weight: 700; letter-spacing: .14em; }
.wphx-readiness__header > strong { display: block; margin: 18px 0 8px; font-family: Georgia, serif; font-size: 40px; line-height: .9; }
.wphx-readiness__header p { margin: 0; font-family: Georgia, serif; font-size: 15px; line-height: 1.45; }
.wphx-readiness .components-panel__body { border-bottom: 0; }
.wphx-readiness .components-toggle-control__help { color: var(--ink); }
.wphx-readiness__panel-title { margin: 16px 0; font-family: Georgia, serif; font-size: 21px; }
.wphx-readiness__priority { margin-top: 22px; padding: 16px; background: var(--ink); color: var(--paper); }
.wphx-readiness__priority > span { display: block; color: var(--cool); font-size: 10px; letter-spacing: .12em; text-transform: uppercase; }
.wphx-readiness__priority > strong { display: block; margin: 8px 0 14px; font-family: Georgia, serif; font-size: 25px; }
.wphx-readiness .wphx-readiness__priority .components-button { background: var(--ink); color: var(--paper); box-shadow: inset 0 0 0 1px var(--paper); }
.wphx-readiness .wphx-readiness__priority .components-button:hover,
.wphx-readiness .wphx-readiness__priority .components-button:focus { background: var(--ink); color: var(--paper); }
.wphx-readiness__footer { display: flex; justify-content: space-between; padding: 12px 16px; border-top: 1px solid var(--ink); font-size: 9px; letter-spacing: .08em; }
.wphx-readiness[data-state="review"] .wphx-readiness__header { box-shadow: inset 5px 0 0 var(--signal); }
@media (prefers-reduced-motion: no-preference) {
  .wphx-readiness__header { transition: box-shadow 160ms ease-out; }
}
';
}
