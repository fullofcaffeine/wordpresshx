package sdk061.fixture;

import wordpress.hx.gutenberg.block.BlockProps;
import wordpress.hx.gutenberg.block.EditAttributes;
import wordpress.hx.gutenberg.block.EditProps;
import wordpress.hx.gutenberg.block.PlainText;
import wordpress.hx.gutenberg.block.SaveProps;
import wordpress.hx.gutenberg.browser.BrowserNode;

final class CalloutBlock {
	public static function edit(props:EditProps<CalloutAttributes>):BrowserNode {
		final attributes = props.attributes;
		return <aside {...BlockProps.edit({className: "wphx-callout wphx-callout--editor"})}>
			<span class="wphx-callout__eyebrow">STATIC / TYPED / NATIVE</span>
			<PlainText
				ariaLabel="Callout label"
				className="wphx-callout__label"
				onChange={next -> EditAttributes.set(props, selected -> selected.label, next)}
				placeholder="NOTE"
				value={attributes.label}
			/>
			<PlainText
				ariaLabel="Callout message"
				className="wphx-callout__message"
				onChange={next -> EditAttributes.set(props, selected -> selected.message, next)}
				placeholder="Write a durable note…"
				value={attributes.message}
			/>
		</aside>;
	}

	public static function save(props:SaveProps<CalloutAttributes>):BrowserNode {
		final attributes = props.attributes;
		return <aside {...BlockProps.save({className: "wphx-callout"})}>
			<span class="wphx-callout__label">{attributes.label}</span>
			<p class="wphx-callout__message">{attributes.message}</p>
		</aside>;
	}

	public static function legacySave(props:SaveProps<LegacyCalloutAttributes>):BrowserNode {
		return <div class="wphx-callout-legacy"><p class="wphx-callout__message">{props.attributes.text}</p></div>;
	}

	public static function migrate(attributes:LegacyCalloutAttributes):CalloutAttributes {
		return CalloutAttributes.migrated("NOTE", attributes.text);
	}

	public static function legacyIsEligible(attributes:LegacyCalloutAttributes):Bool {
		return attributes.text != "";
	}
}
