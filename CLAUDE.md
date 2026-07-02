# nvim-conf

The user's Neovim config. Deployed via `npm run setup` (see README).

## Cross-platform rule

- This config runs on Windows, Linux, and occasionally macOS.
- Anything platform-specific must be guarded (`vim.fn.has("win32")` etc.) and default to
  POSIX behavior everywhere else.
