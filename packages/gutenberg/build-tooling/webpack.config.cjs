const { createRequire } = require("node:module");
const path = require("node:path");

const projectRequire = createRequire(path.join(process.cwd(), "package.json"));
const defaultConfiguration = projectRequire(
  "@wordpress/scripts/config/webpack.config"
);
const DependencyExtractionWebpackPlugin = projectRequire(
  "@wordpress/dependency-extraction-webpack-plugin"
);
const transformTypeScript = projectRequire.resolve(
  "@babel/plugin-transform-typescript"
);

function isBabelLoader(loader) {
  return (
    typeof loader === "string" &&
    loader.includes(`${path.sep}babel-loader${path.sep}`)
  );
}

function adaptBabelUse(use, state) {
  if (Array.isArray(use)) {
    return use.map((entry) => adaptBabelUse(entry, state));
  }
  if (!use || typeof use !== "object" || !isBabelLoader(use.loader)) {
    return use;
  }

  const options = use.options || {};
  const plugins = options.plugins || [];
  const alreadyConfigured = plugins.some((plugin) => {
    const identity = Array.isArray(plugin) ? plugin[0] : plugin;
    return identity === transformTypeScript;
  });
  if (alreadyConfigured) {
    throw new Error(
      "SDK-033 refuses to duplicate the TypeScript transform in Babel"
    );
  }
  state.babelLoaders += 1;
  return {
    ...use,
    options: {
      ...options,
      plugins: [
        ...plugins,
        [
          transformTypeScript,
          {
            allExtensions: true,
            allowDeclareFields: true,
            isTSX: true,
          },
        ],
      ],
    },
  };
}

function adaptRule(rule, state) {
  if (!rule || typeof rule !== "object") {
    return rule;
  }
  return {
    ...rule,
    ...(rule.use === undefined
      ? {}
      : { use: adaptBabelUse(rule.use, state) }),
    ...(Array.isArray(rule.rules)
      ? { rules: rule.rules.map((child) => adaptRule(child, state)) }
      : {}),
    ...(Array.isArray(rule.oneOf)
      ? { oneOf: rule.oneOf.map((child) => adaptRule(child, state)) }
      : {}),
  };
}

function normalizeEntryNames(entry) {
  if (typeof entry === "function") {
    return async (...arguments_) =>
      normalizeEntryNames(await entry(...arguments_));
  }
  if (!entry || typeof entry !== "object" || Array.isArray(entry)) {
    throw new Error("SDK-033 requires the official named-entry object");
  }
  const normalized = {};
  for (const [name, value] of Object.entries(entry)) {
    const nextName = name.replace(/\.(?:[cm]?[jt]sx?)$/, "");
    if (!nextName || Object.hasOwn(normalized, nextName)) {
      throw new Error(`SDK-033 entry-name collision after normalization: ${name}`);
    }
    normalized[nextName] = value;
  }
  return normalized;
}

function enableExternalizedReport(configuration) {
  const plugins = configuration.plugins || [];
  const matches = plugins.filter(
    (plugin) => plugin instanceof DependencyExtractionWebpackPlugin
  );
  if (matches.length !== 1) {
    throw new Error(
      `SDK-033 expected exactly one official dependency-extraction plugin; found ${matches.length}`
    );
  }
  const original = matches[0];
  const state = { babelLoaders: 0 };
  const adapted = {
    ...configuration,
    entry: normalizeEntryNames(configuration.entry),
    module: {
      ...configuration.module,
      rules: (configuration.module?.rules || []).map((rule) =>
        adaptRule(rule, state)
      ),
    },
    plugins: plugins.map((plugin) =>
      plugin === original
        ? new DependencyExtractionWebpackPlugin({ externalizedReport: true })
        : plugin
    ),
  };
  if (state.babelLoaders !== 1) {
    throw new Error(
      `SDK-033 expected exactly one official Babel loader; found ${state.babelLoaders}`
    );
  }
  return adapted;
}

module.exports = Array.isArray(defaultConfiguration)
  ? defaultConfiguration.map(enableExternalizedReport)
  : enableExternalizedReport(defaultConfiguration);
