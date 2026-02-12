local M = {}

local function show_error(msg)
  vim.notify("jq-playground: " .. msg, vim.log.levels.ERROR, {})
end

local function user_preferred_indent(buf)
  local prefer_tabs = not vim.bo[buf].expandtab
  if prefer_tabs then
    return { "--tab" }
  end

  local indent_width = vim.bo[buf].tabstop
  if 0 < indent_width and indent_width < 8 then
    return { "--indent", indent_width }
  end

  return {}
end

local function input_args(input)
  if type(input) == "string" and vim.fn.filereadable(input) == 1 then
    local buf = vim.fn.bufnr(input)
    if buf ~= -1 and vim.api.nvim_buf_is_valid(buf) then
      return nil, vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    end

    return input, nil
  end

  if type(input) == "number" and vim.api.nvim_buf_is_valid(input) then
    return nil, vim.api.nvim_buf_get_lines(input, 0, -1, false)
  end

  show_error("invalid input: " .. input)
end

local function run_query(cmd, input, query_buf, output_buf)
  local cli_args = vim.deepcopy(cmd)

  local filter_lines = vim.api.nvim_buf_get_lines(query_buf, 0, -1, false)
  local filter = table.concat(filter_lines, "\n")
  table.insert(cli_args, filter)

  vim.list_extend(cli_args, user_preferred_indent(output_buf))

  local input_filename, stdin = input_args(input)
  if input_filename then
    table.insert(cli_args, input_filename)
  end

  local on_exit = function(result)
    vim.schedule(function()
      local out = result.code == 0 and result.stdout or result.stderr
      local lines = vim.split(out, "\n", { plain = true })
      vim.api.nvim_buf_set_lines(output_buf, 0, -1, false, lines)
    end)
  end

  local ok, _ = pcall(vim.system, cli_args, { stdin = stdin }, on_exit)
  if not ok then
    show_error("jq is not installed or not on your $PATH")
  end
end

function M.run_query(input)
  local cfg = require("jq-playground.config").config
  local query_buf = vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(query_buf) then
    show_error("invalid query buffer")
    return
  end

  local output_buf = vim.b[query_buf].jqplayground_outputbuf
  local resolved_input = input or vim.b[query_buf].jqplayground_input

  if not (output_buf and vim.api.nvim_buf_is_valid(output_buf)) then
    show_error("missing output buffer; start with :JqPlayground")
    return
  end

  if resolved_input == nil then
    show_error("missing input buffer; start with :JqPlayground")
    return
  end

  run_query(cfg.cmd, resolved_input, query_buf, output_buf)
end

local function resolve_winsize(num, max)
  if num == nil or (1 <= num and num <= max) then
    return num
  elseif 0 < num and num < 1 then
    return math.floor(num * max)
  else
    show_error(string.format("incorrect winsize, received %s of max %s", num, max))
  end
end

local function create_split_buf(opts, before_filetype_callback)
  local buf = vim.fn.bufnr(opts.name)
  if buf == -1 then
    buf = vim.api.nvim_create_buf(true, opts.scratch)

    -- Execute callback before setting filetype to ensure buffer variables are
    -- available to ftplugin scripts and FileType autocmds that get triggered
    if vim.is_callable(before_filetype_callback) then
      before_filetype_callback(buf)
    end

    vim.bo[buf].filetype = opts.filetype
    vim.api.nvim_buf_set_name(buf, opts.name)
  end

  local height = resolve_winsize(opts.height, vim.api.nvim_win_get_height(0))
  local width = resolve_winsize(opts.width, vim.api.nvim_win_get_width(0))

  local winid = vim.api.nvim_open_win(buf, true, {
    split = opts.split_direction,
    width = width,
    height = height,
  })

  return buf, winid
end


function M.init_playground(filename)
  local cfg = require('jq-playground.config').config

  -- check if we're working with YAML
  local curbuf = vim.api.nvim_get_current_buf()
  local match_args = filename and { filename = filename } or { buf = curbuf }
  if vim.filetype.match(match_args) == "yaml" then
    cfg.cmd = { "yq" }
    cfg.output_window.filetype = "yaml"
    cfg.output_window.name = "yq output"
    cfg.query_window.filetype = "yq"
  end

  -- Create output buffer first
  local output_buf, _ = create_split_buf(cfg.output_window)
  vim.api.nvim_buf_set_lines(output_buf, 0, -1, false, {})

  -- And then query buffer
  create_split_buf(cfg.query_window, function(new_buf)
    vim.b[new_buf].jqplayground_inputbuf = curbuf
    vim.b[new_buf].jqplayground_input = filename or curbuf
    vim.b[new_buf].jqplayground_outputbuf = output_buf
  end)
end

return M
