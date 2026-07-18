import { DifferentialApi } from "./index";

const summary = DifferentialApi.summarize("item", [3, 1, 3]);
const description: string = DifferentialApi.describe("SDK-035", summary);
const node = DifferentialApi.Counter({
  initial: 2,
  step: 3,
  label: "Differential count"
});

void description;
void node;
