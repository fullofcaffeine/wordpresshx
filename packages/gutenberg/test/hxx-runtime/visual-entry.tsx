import "@wordpress/components/build-style/style.css";
import { createElement } from "react";
import { createRoot } from "react-dom/client";
import { Main } from "@sdk032/generated";

const root = document.getElementById("root");
if (root === null) {
  throw new Error("SDK-032 visual fixture requires #root");
}
createRoot(root).render(createElement(Main.App));
