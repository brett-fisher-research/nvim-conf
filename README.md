# nvim-conf

My [Neovim](https://neovim.io/) configuration, kept in its own repo so it's easy to set up on any machine — Windows, Linux, or macOS. Minimal and view-first: 5 plugins, core treesitter highlighting, no LSP, no autocomplete, no update nags.

## What's in the config

| Plugin | Role |
| --- | --- |
| [tokyonight.nvim](https://github.com/folke/tokyonight.nvim) | Colorscheme |
| [nvim-tree.lua](https://github.com/nvim-tree/nvim-tree.lua) | File explorer (right side, follows the current file) |
| [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) | Fuzzy finding and live grep |
| [octo.nvim](https://github.com/pwntester/octo.nvim) | GitHub PR review — API-only, never touches the local checkout |
| [render-markdown.nvim](https://github.com/MeanderingProgrammer/render-markdown.nvim) | In-buffer markdown preview, toggleable per buffer |

Plugins are managed by [lazy.nvim](https://github.com/folke/lazy.nvim) (bootstrapped automatically; the update checker is disabled). Syntax highlighting uses Neovim's built-in treesitter — no treesitter plugin.

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
| `<leader>mp` | Toggle markdown preview in the current buffer |
| `<leader>h` | Floating cheatsheet of all of the above |

### Reviewing pull requests

PR review runs on [octo.nvim](https://github.com/pwntester/octo.nvim): everything is fetched from the GitHub API into scratch buffers, so viewing a PR never checks out a branch or touches the working tree — review as many PRs across as many repos as you like with zero local state. Requires the [GitHub CLI](https://cli.github.com/) authenticated (`gh auth login`). Start from `<leader>pl` in any repo.

## Setup on a new machine

### 1. Install prerequisites

- [Neovim](https://neovim.io/) 0.12+ — `winget install Neovim.Neovim` on Windows, `brew install neovim` on macOS, `apt install neovim` (or your distro's package) on Linux
- [git](https://git-scm.com/) — lazy.nvim clones plugins with it
- [Node.js](https://nodejs.org/) — only used to run the setup script
- [GitHub CLI](https://cli.github.com/) — only needed for the `:PR` flow
- Linux only: a clipboard provider — `xclip` or `xsel` on X11, `wl-clipboard` on Wayland. Yanks use the system clipboard (`clipboard=unnamedplus`); Windows and macOS need nothing extra.

### 2. Clone and run setup

```sh
git clone https://github.com/brett-fisher-research/nvim-conf.git
cd nvim-conf
npm run setup
```

The setup script is idempotent — run it as many times as you like (e.g. after pulling config changes). It copies `nvim/` to the platform config path: `%LOCALAPPDATA%\nvim` on Windows, `$XDG_CONFIG_HOME/nvim` (or `~/.config/nvim`) elsewhere. On first launch lazy.nvim installs the plugins.

## Adding a language

Install a treesitter parser for the language (a compiled `parser/<lang>.so`/`.dll` anywhere on the runtimepath) and core treesitter highlights it automatically — a `FileType` autocmd calls `vim.treesitter.start()` whenever a parser exists, and stays silent when one doesn't. Common languages (lua, vimscript, C, markdown) ship with Neovim.

## Making changes

Edit the config under `nvim/` in this repo, then re-run `npm run setup` to apply it. This keeps the repo as the single source of truth instead of editing the installed copy directly.
