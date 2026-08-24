import wordpress.hx.i18n.Messages;

class Main {
	static function main():Void {
		final userContent = "books.user-content";
		Messages.text({
			key: userContent,
			defaultText: "Unsafe dynamic key",
			comment: "This declaration must fail before runtime.",
			domain: "wordpresshx-sdk055"
		});
	}
}
