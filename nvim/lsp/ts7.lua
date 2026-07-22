-- TypeScript 7 native language server (TypeScript + JavaScript + React).
--
-- TS7 is the Go rewrite: it ships NO tsserver.js, so the compiler binary IS the
-- language server, spoken over stdio as `tsc --lsp --stdio`. That rules out
-- typescript-language-server (it hard-fails looking for a tsserver.js) and vtsls
-- (it bundles TypeScript 5.x and can never load a TS7 project's compiler).
--
-- Installed globally: npm i -g typescript
local inlay_hints = {
  parameterNames = { enabled = "literals" },
  parameterTypes = { enabled = true },
  variableTypes = { enabled = true },
  propertyDeclarationTypes = { enabled = true },
  functionLikeReturnTypes = { enabled = true },
  enumMemberValues = { enabled = true },
}

return {
  cmd = { require("brot.bin").npm("tsc"), "--lsp", "--stdio" },

  -- React needs nothing beyond these filetypes. Nvim 0.12 maps .tsx ->
  -- typescriptreact and .jsx -> javascriptreact natively; the legacy compound
  -- filetypes (typescript.tsx) are not used.
  filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },

  -- Lockfile tier FIRST (nvim 0.11+ nested lists are priority tiers). tsc7
  -- resolves each package's own tsconfig internally, so one process serves a
  -- whole monorepo; rooting at tsconfig.json instead splits a monorepo's apps
  -- apart and breaks projects whose root tsconfig only includes a subdir.
  root_markers = {
    { "package-lock.json", "bun.lock", "bun.lockb", "pnpm-lock.yaml", "yarn.lock" },
    { "tsconfig.json", "jsconfig.json" },
    "package.json",
    ".git",
  },

  -- Inlay hints are requested here so `:lua vim.lsp.inlay_hint.enable(true)`
  -- works on demand, but nothing switches them on - nvim's default (off)
  -- stands. TS7 reads the VS Code-shaped keys below, NOT tsserver's legacy
  -- `includeInlay*` preference names - those are silently ignored and no hints
  -- ever arrive.
  settings = {
    typescript = { inlayHints = inlay_hints },
    javascript = { inlayHints = inlay_hints },
  },
}
