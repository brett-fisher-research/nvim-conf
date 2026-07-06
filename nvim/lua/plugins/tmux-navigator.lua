-- Nvim half of vim-tmux-navigator: Ctrl+hjkl crosses nvim splits and tmux
-- panes seamlessly (tmux half already installed). Lazy-loads on the nav cmds
-- and the four keys so it costs nothing until first use.
return {
  "christoomey/vim-tmux-navigator",
  cmd = {
    "TmuxNavigateLeft",
    "TmuxNavigateDown",
    "TmuxNavigateUp",
    "TmuxNavigateRight",
  },
  keys = {
    { "<C-h>", "<cmd>TmuxNavigateLeft<cr>", desc = "Navigate split/pane left" },
    { "<C-j>", "<cmd>TmuxNavigateDown<cr>", desc = "Navigate split/pane down" },
    { "<C-k>", "<cmd>TmuxNavigateUp<cr>", desc = "Navigate split/pane up" },
    { "<C-l>", "<cmd>TmuxNavigateRight<cr>", desc = "Navigate split/pane right" },
  },
}
