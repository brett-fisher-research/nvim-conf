-- ruff: Python lint + format + import sorting.
-- Hover is suppressed on attach (see init.lua's LspAttach handler) so
-- basedpyright alone answers K. Bare command name resolves via PATHEXT on
-- Windows and PATH elsewhere - no platform branch.
return {
  cmd = { "ruff", "server" },
  filetypes = { "python" },
  root_markers = {
    "pyproject.toml",
    "ruff.toml",
    ".ruff.toml",
    "setup.py",
    "setup.cfg",
    "requirements.txt",
    ".git",
  },
  init_options = {
    settings = {
      -- Empty = ruff's defaults, read from the project's pyproject/ruff.toml.
      lint = { enable = true },
      organizeImports = true,
    },
  },
}
