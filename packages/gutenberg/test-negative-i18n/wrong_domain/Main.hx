import wordpress.hx.i18n.Messages;

class Main {
	static function main():Void {
		Messages.text({
			key: "books.wrong-domain",
			defaultText: "Wrong domain",
			comment: "This declaration must reject uppercase domain text.",
			domain: "WordPressHx-SDK055"
		});
	}
}
