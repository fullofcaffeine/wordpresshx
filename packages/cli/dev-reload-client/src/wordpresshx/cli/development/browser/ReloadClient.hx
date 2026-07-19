package wordpresshx.cli.development.browser;

import js.Browser;
import js.html.Event;
import js.html.EventSource;

/** Development-only full-page reload client compiled to JavaScript by Genes. */
class ReloadClient {
	static function main():Void {
		final script = Browser.document.currentScript;
		if (script == null) {
			return;
		}
		final eventsUrl = script.getAttribute("data-wordpresshx-reload-events");
		if (eventsUrl == null || eventsUrl.length == 0) {
			return;
		}
		final source = new EventSource(eventsUrl);
		source.addEventListener("open", (_:Event) -> Browser.document.documentElement.setAttribute("data-wordpresshx-reload-ready", "true"));
		source.addEventListener("wordpresshx-reload", (_:Event) -> {
			source.close();
			Browser.window.location.reload();
		});
		Browser.window.addEventListener("pagehide", (_:Event) -> source.close());
	}
}
