import { act, createElement } from "react";
import { createRoot } from "react-dom/client";
import type { Root } from "react-dom/client";
import { Main } from "@sdk032/generated";

let activeRoot: Root | null = null;

export async function mount(container: HTMLElement): Promise<void> {
  if (activeRoot !== null) {
    throw new Error("SDK-032 fixture is already mounted");
  }
  activeRoot = createRoot(container);
  await act(async () => {
    activeRoot?.render(createElement(Main.App));
  });
}

export async function unmount(): Promise<void> {
  if (activeRoot === null) {
    return;
  }
  const root = activeRoot;
  activeRoot = null;
  await act(async () => {
    root.unmount();
  });
}

export async function runInAct(effect: () => void | Promise<void>): Promise<void> {
  await act(async () => {
    await effect();
  });
}
