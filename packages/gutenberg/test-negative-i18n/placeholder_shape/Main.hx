import wordpress.hx.i18n.Messages;

class Main {
	static function main():Void {
		Messages.string({
			key: "books.bad-placeholder",
			defaultText: "Open %s",
			comment: "This declaration must require a numbered placeholder.",
			domain: "wordpresshx-sdk055"
		});
	}
}
