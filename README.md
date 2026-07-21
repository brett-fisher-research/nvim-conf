# nvim-conf

My [Neovim](https://neovim.io/) configuration, kept in its own repo so it's easy to set up on any machine - Windows, Linux, or macOS. Minimal: 8 plugins, core treesitter highlighting, Neovim's built-in LSP client (zero LSP plugins), no update nags.

## What's in the config

| Plugin | Role |
| --- | --- |
| [tokyonight.nvim](https://github.com/folke/tokyonight.nvim) | Colorscheme (also styles diagnostic undercurls) |
| [nvim-tree.lua](https://github.com/nvim-tree/nvim-tree.lua) | File explorer (right side, follows the current file) |
| [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) | Fuzzy finding, live grep, git pickers |
| [octo.nvim](https://github.com/pwntester/octo.nvim) | GitHub PR review - API-only, never touches the local checkout |
| [render-markdown.nvim](https://github.com/MeanderingProgrammer/render-markdown.nvim) | In-buffer markdown preview, toggleable per buffer |
| [gitsigns.nvim](https://github.com/lewis6991/gitsigns.nvim) | Signcolumn git hunks and hunk preview |
| [diffview.nvim](https://github.com/sindrets/diffview.nvim) | Full-window git diff view |
| [vim-tmux-navigator](https://github.com/christoomey/vim-tmux-navigator) | Ctrl+hjkl across nvim splits and tmux panes |

Plugins are managed by [lazy.nvim](https://github.com/folke/lazy.nvim) (bootstrapped automatically; the update checker is disabled). Syntax highlighting uses Neovim's built-in treesitter, no treesitter plugin. Language intelligence uses Neovim 0.12's built-in LSP client, no lspconfig, no package manager, no completion plugin.

### Keymaps

Leader is `Space`.

| Keys | Action |
| --- | --- |
| `<leader>e` | Toggle file explorer |
| `<leader>ff` | Fuzzy find files in cwd |
| `<leader>fr` | Fuzzy find recent files |
| `<leader>fs` | Live grep in cwd |
| `<leader>fc` | Grep string under cursor |
| `Ctrl+k` / `Ctrl+j` | Move up/down in telescope results (insert mode) |
| `<leader>pl` | List ALL open PRs across the account's repos (Enter opens one) |
| `<leader>pd` | Diff the open PR |
| `<leader>po` | Open a PR by number |
| `<leader>pc` | PR checks (CI status) |
| `<leader>pb` | Open the PR in the browser |
| `<leader>mp` | Toggle markdown preview in the current buffer |
| `<leader>h` | Floating cheatsheet of all of the above |

Code intelligence (LSP). `gd` and `gR` are the only additions; the rest are Neovim 0.12 defaults, kept as-is.

| Keys | Action |
| --- | --- |
| `gd` | Go to definition |
| `gR` | List references |
| `K` | Hover documentation |
| `grn` | Rename symbol |
| `gra` | Code action |
| `grr` / `gri` / `grt` | References / implementations / type definition |
| `gO` | Document symbols |
| `]d` / `[d` | Next / previous diagnostic |
| `Ctrl+w d` | Diagnostic under the cursor in a float |
| `Ctrl+x Ctrl+o` | Completion (also autotriggers as you type) |

### Reviewing pull requests

PR review runs on [octo.nvim](https://github.com/pwntester/octo.nvim): everything is fetched from the GitHub API into scratch buffers, so viewing a PR never checks out a branch or touches the working tree — review as many PRs across as many repos as you like with zero local state. Requires the [GitHub CLI](https://cli.github.com/) authenticated (`gh auth login`). Start from `<leader>pl` in any repo.

## Setup on a new machine

### 1. Install prerequisites

- [Neovim](https://neovim.io/) 0.12+ — `winget install Neovim.Neovim` on Windows, `brew install neovim` on macOS, `apt install neovim` (or your distro's package) on Linux
- [git](https://git-scm.com/) — lazy.nvim clones plugins with it
- [Node.js](https://nodejs.org/) — only used to run the setup script
- [GitHub CLI](https://cli.github.com/) - only needed for the PR flow
- Language servers, optional per language - Python wants [uv](https://docs.astral.sh/uv/): `uv tool install basedpyright && uv tool install ruff`. Nothing breaks when a server is missing; that filetype just gets no diagnostics.
- Linux only: a clipboard provider — `xclip` or `xsel` on X11, `wl-clipboard` on Wayland. Yanks use the system clipboard (`clipboard=unnamedplus`); Windows and macOS need nothing extra.

### 2. Clone and run setup

```sh
git clone https://github.com/brett-fisher-research/nvim-conf.git
cd nvim-conf
npm run setup
```

The setup script is idempotent — run it as many times as you like (e.g. after pulling config changes). It copies `nvim/` to the platform config path: `%LOCALAPPDATA%\nvim` on Windows, `$XDG_CONFIG_HOME/nvim` (or `~/.config/nvim`) elsewhere. On first launch lazy.nvim installs the plugins.

## Language servers

Diagnostics render as a red undercurl plus a terse inline hint on every offending line, with the full message expanded under the cursor's line only. Python ships configured:

| Server | Owns |
| --- | --- |
| [basedpyright](https://docs.basedpyright.com/) | Types, hover docs, goto-definition, references, completion |
| [ruff](https://docs.astral.sh/ruff/) | Lint, format, import sorting (its hover is suppressed so `K` reaches basedpyright) |

Install both with [uv](https://docs.astral.sh/uv/): `uv tool install basedpyright && uv tool install ruff`.

### Adding any language

One file per server, no plugin, no package manager:

1. Install the server binary however that language distributes it (`uv tool install`, `npm i -g`, `brew install`, ...).
2. Verify Neovim can see it: `:echo exepath("<binary>")` must print a path.
3. Drop `nvim/lsp/<name>.lua` returning a table with `cmd`, `filetypes`, `root_markers` (copy `nvim/lsp/ruff.lua` as the template). Use the bare binary name in `cmd`; Windows resolves it through PATHEXT.
4. Add `"<name>"` to the `vim.lsp.enable({ ... })` list in `nvim/init.lua`.
5. Re-run `npm run setup`, reopen a file of that filetype, confirm with `:checkhealth vim.lsp`.

`npm test` fails if a name is enabled without a matching `nvim/lsp/<name>.lua`.

## Adding syntax highlighting for a language

Install a treesitter parser for the language (a compiled `parser/<lang>.so`/`.dll` anywhere on the runtimepath) and core treesitter highlights it automatically: a `FileType` autocmd calls `vim.treesitter.start()` whenever a parser exists, and stays silent when one doesn't. Common languages (lua, vimscript, C, markdown) ship with Neovim.

## Making changes

Edit the config under `nvim/` in this repo, then re-run `npm run setup` to apply it. This keeps the repo as the single source of truth instead of editing the installed copy directly. Run `npm test` first: the suite loads the real `nvim/init.lua` headlessly and drives its keymaps, diagnostics config, LSP attach handler, and cheatsheet.
