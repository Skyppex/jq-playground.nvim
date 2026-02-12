local M = {}

function M.open(filename)
  require("jq-playground.playground").init_playground(filename)
end

function M.run_query(filename)
  require("jq-playground.playground").run_query(filename)
end

function M.setup(opts)
  local confmod = require("jq-playground.config")

  confmod.config = vim.tbl_deep_extend("force", confmod.default_config, opts or {})
end

return M
