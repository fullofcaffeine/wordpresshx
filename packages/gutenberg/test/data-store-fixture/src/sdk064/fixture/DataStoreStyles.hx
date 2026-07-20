package sdk064.fixture;

class DataStoreStyles {
	public static final css = '
.wphx-todo-lab {
  --ink: #132f3f;
  --paper: #f5f0e4;
  --signal: #c73620;
  --mint: #66d3b1;
  --line: rgba(19, 47, 63, .24);
  background: var(--paper);
  border-block: 1px solid var(--ink);
  color: var(--ink);
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
}
.wphx-todo-lab__header { padding: 22px 20px 18px; border-bottom: 1px solid var(--ink); }
.wphx-todo-lab__eyebrow { color: var(--signal); font-size: 10px; font-weight: 700; letter-spacing: .14em; }
.wphx-todo-lab__header h2 { margin: 14px 0 8px; font-family: Georgia, serif; font-size: 34px; line-height: .94; }
.wphx-todo-lab__header p { margin: 0; font-family: Georgia, serif; font-size: 14px; line-height: 1.45; }
.wphx-todo-lab__meter { display: grid; grid-template-columns: 1fr auto; gap: 12px; align-items: end; padding: 14px 20px; border-bottom: 1px solid var(--ink); }
.wphx-todo-lab__meter strong { font-family: Georgia, serif; font-size: 28px; }
.wphx-todo-lab__meter span { font-size: 9px; letter-spacing: .1em; text-transform: uppercase; }
.wphx-todo-lab__tasks { margin: 0; padding: 0; list-style: none; }
.wphx-todo-lab__task { display: grid; grid-template-columns: 28px 1fr; gap: 10px; align-items: center; padding: 11px 20px; border-bottom: 1px solid var(--line); }
.wphx-todo-lab__task .components-button { min-width: 28px; height: 28px; justify-content: center; padding: 0; border: 1px solid var(--ink); border-radius: 50%; color: var(--ink); }
.wphx-todo-lab__task[data-state="complete"] span { text-decoration: line-through; opacity: .58; }
.wphx-todo-lab__task[data-state="complete"] .components-button { background: var(--mint); }
.wphx-todo-lab .components-panel__body { border-bottom: 0; }
.wphx-todo-lab .components-toggle-control__help { color: var(--ink); }
.wphx-todo-lab__priority { display: grid; gap: 10px; margin: 18px 0; padding: 15px; background: var(--ink); color: var(--paper); }
.wphx-todo-lab__priority strong { color: var(--mint); font-family: Georgia, serif; font-size: 24px; text-transform: uppercase; }
.wphx-todo-lab__priority .components-button { color: var(--paper); box-shadow: inset 0 0 0 1px var(--paper); }
.wphx-todo-lab__sync { padding: 14px; border: 1px solid var(--ink); }
.wphx-todo-lab__sync[data-state="error"] { border-color: var(--signal); box-shadow: inset 4px 0 0 var(--signal); }
.wphx-todo-lab__sync[data-state="ready"] { box-shadow: inset 4px 0 0 var(--mint); }
.wphx-todo-lab__sync p { min-height: 38px; margin: 0 0 12px; font-family: Georgia, serif; font-size: 13px; line-height: 1.4; }
.wphx-todo-lab__footer { display: flex; justify-content: space-between; padding: 11px 16px; border-top: 1px solid var(--ink); font-size: 9px; letter-spacing: .08em; }
@media (prefers-reduced-motion: no-preference) {
  .wphx-todo-lab__task span, .wphx-todo-lab__sync { transition: opacity 150ms ease-out, box-shadow 150ms ease-out; }
}
';
}
