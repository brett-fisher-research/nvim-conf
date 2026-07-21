-- Binary-name helper shared by the nvim/lsp/<name>.lua server configs.
--
-- npm writes THREE shims per global package on Windows (a bare extensionless sh
-- script, a .cmd and a .ps1). libuv's PATH search picks between them
-- nondeterministically and hands the bare sh script to CreateProcess, so
-- vim.lsp.enable with a bare name dies with ENOENT. Naming the .cmd explicitly
-- is the only reliable spelling on win32.
--
-- uv-installed servers (basedpyright, ruff) are real .exe files and must keep
-- their bare names - PATHEXT resolves those correctly on every platform.
local M = {}

--- Resolve an npm-installed binary name for the current platform.
--- @param name string bare binary name, e.g. "tsc"
--- @return string name on POSIX, name .. ".cmd" on Windows
function M.npm(name)
  if vim.fn.has("win32") == 1 then
    return name .. ".cmd"
  end
  return name
end

return M
