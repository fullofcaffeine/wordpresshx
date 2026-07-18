import { createRoot } from "@wordpress/element";

import { EditorPanel } from "./sdk033/fixture/EditorPanel";

declare global {
  interface Window {
    wordpressHxG24SourceCorrelationProbe?: boolean;
  }
}

if (window.wordpressHxG24SourceCorrelationProbe === true) {
  EditorPanel.sourceCorrelationProbe();
}

const container = document.getElementById("wordpresshx-sdk033-proof");
if (container !== null) {
  createRoot(container).render(<EditorPanel.App />);
}
