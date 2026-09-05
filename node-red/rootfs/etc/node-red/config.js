const config = require("/config/settings.js");
const fs = require("fs");
const options = JSON.parse(fs.readFileSync("/data/options.json", "utf8"));
const bcrypt = require("bcryptjs");

if ("theme" in options) {
  if (options.theme !== "default") {
    // The "dark" theme was renamed to "dark-modern" in theme-collection v5.
    // Keep applying the correct theme when the deprecated value is still set.
    config.editorTheme.theme =
      options.theme === "dark" ? "dark-modern" : options.theme;
  }
}

// Sane and required defaults for the add-on
config.debugUseColors = false;
config.flowFile = "flows.json";
config.nodesDir = "/config/nodes";
config.uiHost = "127.0.0.1";
config.uiPort = 46836;
config.userDir = "/config/";

//Set path for HTTP_Nodes to be served from avoiding lua auth
config.httpNodeRoot = "/endpoint";

// Disable authentication, let HA handle that
//config.adminAuth = null;
// Secure admin node
if (config.adminAuth == null && (options.http_admin.username || (options.users && options.users.length > 0))) {
  config.adminAuth = {
    type: "credentials",
    users: []
  };
  if (options.http_admin.username) {
    config.adminAuth.users.push({
      username: options.http_admin.username,
      password: bcrypt.hashSync(options.http_admin.password),
      permissions: "*",
    });
  }
  if (options.users && options.users.length > 0) {
    options.users.forEach(function(user) {
      if (user.username) {
        config.adminAuth.users.push({
          username: user.username,
          password: bcrypt.hashSync(user.password),
          permissions: user.permissions || "*",
        });
      }
    });
  }
}
// Disable SSL, since the add-on handles that
config.https = null;

// Credential secret
if (options.credential_secret) {
  config.credentialSecret = options.credential_secret;
}

// Secure HTTP node
if (options.http_node.username) {
  config.httpNodeAuth = {
    user: options.http_node.username,
    pass: bcrypt.hashSync(options.http_node.password),
  };
}

// Secure static HTTP
if (options.http_static.username) {
  config.httpStaticAuth = {
    user: options.http_static.username,
    pass: bcrypt.hashSync(options.http_static.password),
  };
}

// Set debug level
if (options.log_level) {
  config.logging.console.level = options.log_level.toLowerCase();
  if (config.logging.console.level === "warning") {
    config.logging.console.level = "warn";
  }
}

module.exports = config;
