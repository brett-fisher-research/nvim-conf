-- basedpyright: Python types, hovers, goto-definition, find-references.
-- Consumed by vim.lsp.enable("basedpyright") in init.lua (nvim 0.12 built-in
-- LSP client, no plugins). Bare command name on purpose: Windows resolves the
-- .exe/.cmd through PATHEXT, so no platform branch is needed.
return {
  cmd = { "basedpyright-langserver", "--stdio" },
  filetypes = { "python" },
  root_markers = {
    "pyproject.toml",
    "setup.py",
    "setup.cfg",
    "requirements.txt",
    "Pipfile",
    "pyrightconfig.json",
    ".git",
  },
  settings = {
    basedpyright = {
      -- ruff owns import sorting; two servers fighting over it is churn.
      disableOrganizeImports = true,
      analysis = {
        typeCheckingMode = "standard",
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
        diagnosticMode = "openFilesOnly",
      },
    },
  },
}
