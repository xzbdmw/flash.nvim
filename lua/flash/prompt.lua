local Config = require("flash.config")

---@class Flash.Prompt
---@field win window
---@field buf buffer
local M = {}

local ns = vim.api.nvim_create_namespace("flash_prompt")

function M.visible()
  return M.win and vim.api.nvim_win_is_valid(M.win) and M.buf and vim.api.nvim_buf_is_valid(M.buf)
end

function M.show()
  if M.visible() then
    return
  end
  require("flash.highlight")

  M.buf = vim.api.nvim_create_buf(false, true)
  vim.bo[M.buf].buftype = "nofile"
  vim.bo[M.buf].bufhidden = "wipe"
  vim.bo[M.buf].filetype = "flash_prompt"

  local config = vim.deepcopy(Config.prompt.win_config)

  if config.width <= 1 then
    config.width = config.width * vim.go.columns
  end

  if config.row < 0 then
    config.row = vim.go.lines + config.row
  end

  if config.col < 0 then
    config.col = vim.go.columns + config.col
  end

  config = vim.tbl_extend("force", config, {
    style = "minimal",
    focusable = false,
    noautocmd = true,
    hide = true,
  })

  M.win = vim.api.nvim_open_win(M.buf, false, config)
  vim.wo[M.win].winhighlight = "Normal:FlashPrompt"
end

function M.hide()
  vim.g.treesitter_search = false
  vim.o.scrolloff = 6
  vim.wo.winbar = vim.g.flash_winbar
  vim.api.nvim_exec_autocmds("User", {
    pattern = "FlashHide",
  })
  if M.win and vim.api.nvim_win_is_valid(M.win) then
    vim.api.nvim_win_close(M.win, true)
    M.win = nil
  end
  if M.buf and vim.api.nvim_buf_is_valid(M.buf) then
    vim.api.nvim_buf_delete(M.buf, { force = true })
    M.buf = nil
  end
end

function M.jump_to_next_match(hl)
  local state = _G.flash_state
  if state == nil then
    return
  end
  table.sort(state.results, function(a, b)
    if a.pos[1] ~= b.pos[1] then
      return a.pos[1] < b.pos[1]
    else
      return a.pos[2] < b.pos[2]
    end
  end)
  for _, match in ipairs(state.results) do
    local cur_row, cur_col = unpack(vim.api.nvim_win_get_cursor(0))
    local match_row, match_col = match.pos[1], match.pos[2]
    if match_row > cur_row or (match_row == cur_row and match_col > cur_col) then
      vim.api.nvim_win_set_cursor(0, { match_row, match_col })
      break
    end
  end
  hl = false
  if not hl then
    return
  end
  local ns = vim.api.nvim_create_namespace("flash_match")
  vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
  for _, match in ipairs(state.results) do
    local buf = vim.api.nvim_win_get_buf(match.win)

    local highlight = state.opts.highlight.matches
    if match.highlight ~= nil then
      highlight = match.highlight
    end
    if highlight then
      vim.api.nvim_buf_set_extmark(buf, ns, match.pos[1] - 1, match.pos[2], {
        end_row = match.end_pos[1] - 1,
        end_col = match.end_pos[2] + 1,
        hl_group = match.pos[1] == vim.api.nvim_win_get_cursor(0)[1]
            and match.pos[2] == vim.api.nvim_win_get_cursor(0)[2]
            and state.opts.highlight.groups.current
          or state.opts.highlight.groups.match,
        strict = false,
        priority = state.opts.highlight.priority + 1,
      })
    end
  end
end

function M.jump_to_prev_match(hl)
  local state = _G.flash_state
  if state == nil then
    return
  end
  table.sort(state.results, function(a, b)
    if a.pos[1] ~= b.pos[1] then
      return a.pos[1] > b.pos[1]
    else
      return a.pos[2] > b.pos[2]
    end
  end)
  for _, match in ipairs(state.results) do
    local cur_row, cur_col = unpack(vim.api.nvim_win_get_cursor(0))
    local match_row, match_col = match.pos[1], match.pos[2]
    if match_row < cur_row or (match_row == cur_row and match_col < cur_col) then
      vim.api.nvim_win_set_cursor(0, { match_row, match_col })
      break
    end
  end
  hl = false
  if not hl then
    return
  end
  local ns = vim.api.nvim_create_namespace("flash_match")
  vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
  for _, match in ipairs(state.results) do
    local buf = vim.api.nvim_win_get_buf(match.win)

    local highlight = state.opts.highlight.matches
    if match.highlight ~= nil then
      highlight = match.highlight
    end
    if highlight then
      vim.api.nvim_buf_set_extmark(buf, ns, match.pos[1] - 1, match.pos[2], {
        end_row = match.end_pos[1] - 1,
        end_col = match.end_pos[2] + 1,
        hl_group = match.pos[1] == vim.api.nvim_win_get_cursor(0)[1]
            and match.pos[2] == vim.api.nvim_win_get_cursor(0)[2]
            and state.opts.highlight.groups.current
          or state.opts.highlight.groups.match,
        strict = false,
        priority = state.opts.highlight.priority + 1,
      })
    end
  end
end

---@param pattern string
function M.set(pattern)
  M.show()
  local text = vim.deepcopy(Config.prompt.prefix)
  text[#text + 1] = { pattern }

  local str = ""
  for _, item in ipairs(text) do
    str = str .. item[1]
  end
  vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, { str })

  if vim.wo.winbar ~= "" and vim.g.flash_winbar ~= "" then
    local winbar = vim.g.flash_winbar
    local index = string.find(winbar, [[%=]], nil, true)
    local new_winbar
    local name = "  %#FlashPromptIcon#⚡" .. "%#FlashPrompt#" .. str .. "%#Normal#" .. " "
    if index == nil then
      new_winbar = winbar .. name
    else
      new_winbar = winbar:sub(1, index - 1) .. name .. winbar:sub(index)
    end
    vim.wo.winbar = new_winbar
  end

  vim.api.nvim_buf_clear_namespace(M.buf, ns, 0, -1)
  local col = 0
  for _, item in ipairs(text) do
    local width = vim.fn.strlen(item[1])
    if item[2] then
      vim.api.nvim_buf_set_extmark(M.buf, ns, 0, col, {
        hl_group = item[2],
        end_col = col + width,
      })
    end
    col = col + width
  end
end

return M
