export let liveValue = 7;

export function increment() {
  liveValue += 1;
}

export function setupCount() {
  return globalThis.__wordpressHxSdk031SetupCount ?? 0;
}
