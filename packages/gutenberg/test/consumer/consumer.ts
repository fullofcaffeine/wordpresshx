import { BrowserApi } from "./src-gen/index";

const api = new BrowserApi("Hello");
const prefix: string = api.prefix;
const greeting: string = api.greet("Haxe");
const value: number = api.identity(42);
const missing: string = api.nullableLabel(null);
const signals = api.observeSignals();

void greeting;
void prefix;
void value;
void missing;
void signals;

// @ts-expect-error Constructor input remains a string.
new BrowserApi(42);

// @ts-expect-error The private implementation is not a public ESM contract.
api.implementationDetail();
