import { createRoot } from "@wordpress/element";

import { EditorPanel } from "./sdk033/fixture/EditorPanel";

const container = document.getElementById("wordpresshx-sdk033-proof");
if (container !== null) {
  createRoot(container).render(<EditorPanel.App />);
}
