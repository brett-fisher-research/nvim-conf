return {
  "MeanderingProgrammer/render-markdown.nvim",
  -- No nvim-treesitter dependency on purpose: nvim 0.10+ bundles the markdown
  -- and markdown_inline parsers this plugin needs.
  ft = { "markdown" },
  keys = {
    { "<leader>mp", "<cmd>RenderMarkdown buf_toggle<cr>", desc = "Markdown preview toggle" },
  },
  opts = {},
}
