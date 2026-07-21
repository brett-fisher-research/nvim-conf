-- eslint: the JS/TS analogue of ruff. Lint diagnostics plus the
-- source.fixAll.eslint code action the BufWritePre pipeline in init.lua runs.
--
-- Installed globally: npm i -g vscode-langservers-extracted
-- Flat config (eslint.config.js) is auto-detected; there is no opt-in knob.
-- Formatting stays off - prettier owns that (see init.lua).
return {
  cmd = { require("brot.bin").npm("vscode-eslint-language-server"), "--stdio" },
  filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
  root_markers = {
    {
      "eslint.config.js",
      "eslint.config.mjs",
      "eslint.config.cjs",
      "eslint.config.ts",
      ".eslintrc.js",
      ".eslintrc.cjs",
      ".eslintrc.json",
    },
    "package.json",
    ".git",
  },

  -- Without settings.workspaceFolder the server throws
  -- `The "path" argument must be of type string. Received undefined` on the
  -- very first diagnostic request. nvim resolves root_dir after the config
  -- table is built, so it can only be filled in here.
  before_init = function(_, config)
    config.settings = config.settings or {}
    config.settings.workspaceFolder = {
      uri = config.root_dir,
      name = vim.fn.fnamemodify(config.root_dir, ":t"),
    }
  end,

  settings = {
    validate = "on",
    format = false,
    quiet = false,
    run = "onType",
    problems = { shortenToSingleLine = false },
    codeAction = {
      disableRuleComment = { enable = true, location = "separateLine" },
      showDocumentation = { enable = true },
    },
    codeActionOnSave = { enable = false, mode = "all" },
    nodePath = "",
    workingDirectory = { mode = "location" },
  },
}
