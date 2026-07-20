declare module "@wordpress/block-editor" {
  import type { ComponentType } from "react";

  export type StaticBlockElementProps = {
    readonly className?: string;
  };

  export type StaticPlainTextProps = {
    readonly value: string;
    readonly onChange: (next: string) => void;
    readonly className?: string;
    readonly placeholder?: string;
    readonly "aria-label"?: string;
  };

  export interface StaticUseBlockProps {
    (props: StaticBlockElementProps): StaticBlockElementProps;
    save(props: StaticBlockElementProps): StaticBlockElementProps;
  }

  export const PlainText: ComponentType<StaticPlainTextProps>;
  export const useBlockProps: StaticUseBlockProps;
}

declare module "@wordpress/blocks" {
  export function registerBlockType(
    name: string,
    settings: object,
  ): object | undefined;
}
