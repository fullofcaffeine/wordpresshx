import wordpress.hx.hxx.prototype.ServerHxx;
import wordpress.hx.hxx.prototype.ServerSnapshot;

class Main {
	public static function main():Void {
		final title:String = "Typed markup";
		final pageClass:String = "landing";
		final count:Int = 3;
		final showDetails:Bool = true;
		final panelDefaults:{highlighted:Bool} = {highlighted: true};
		final lines:Array<String> = ["first", "second"];
		final snapshot:ServerSnapshot = ServerHxx.render(<main class={pageClass}>
        <Panel title={title} count={count} {...panelDefaults}>
          <header>
            <h1>{title}</h1>
          </header>
          <body>
            <>
              <p>{title}</p>
              {...lines}
            </>
          </body>
        </Panel>
        <if {showDetails}>
          <Inline label={title}>{count}</Inline>
        </if>
      </main>);
		Sys.println(snapshot.serialized());
	}
}
