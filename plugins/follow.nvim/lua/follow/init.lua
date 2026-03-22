local M = {}

local group = vim.api.nvim_create_augroup("follow_changes", { clear = true })
local state = {
  enabled = false,
  root = nil,
  files = {},
}

local function file_mtime(path)
  local stat = vim.uv.fs_stat(path)
  if not stat or stat.type ~= "file" then
    return nil
  end

  local mtime = stat.mtime
  if type(mtime) == "table" then
    return (mtime.sec or 0) * 1000000000 + (mtime.nsec or 0)
  end

  return mtime
end

local function read_lines(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    return {}
  end
  return lines
end

local function snapshot_file(path)
  local mtime = file_mtime(path)
  if not mtime then
    return nil
  end

  return {
    mtime = mtime,
    lines = read_lines(path),
  }
end

local function snapshot_root(root)
  local files = {}
  local paths = vim.fn.globpath(root, "**/*", false, true)

  for _, path in ipairs(paths) do
    if vim.fn.filereadable(path) == 1 then
      local snap = snapshot_file(path)
      if snap then
        files[path] = snap
      end
    end
  end

  return files
end

local function first_changed_line(old_lines, new_lines)
  local max_len = math.max(#old_lines, #new_lines)
  for i = 1, max_len do
    if old_lines[i] ~= new_lines[i] then
      return i
    end
  end
  return 1
end

local function jump_to_latest()
  if not state.enabled or not state.root then
    return
  end

  local current = snapshot_root(state.root)
  local latest = nil

  for path, snap in pairs(current) do
    local previous = state.files[path]
    if not previous or previous.mtime ~= snap.mtime then
      local row = first_changed_line(previous and previous.lines or {}, snap.lines)
      if not latest or snap.mtime > latest.mtime then
        latest = {
          path = path,
          row = row,
          mtime = snap.mtime,
        }
      end
    end
  end

  state.files = current

  if not latest then
    return
  end

  vim.cmd("checktime")

  if vim.api.nvim_buf_get_name(0) ~= latest.path then
    vim.cmd("edit " .. vim.fn.fnameescape(latest.path))
  end

  local line_count = vim.api.nvim_buf_line_count(0)
  local row = math.min(math.max(latest.row, 1), math.max(line_count, 1))
  vim.api.nvim_win_set_cursor(0, { row, 0 })
end

function M.start()
  state.enabled = true
  state.root = vim.fn.getcwd()
  state.files = snapshot_root(state.root)

  vim.opt.autoread = true
  vim.api.nvim_clear_autocmds({ group = group })
  vim.api.nvim_create_autocmd("FocusGained", {
    group = group,
    callback = jump_to_latest,
  })
  vim.api.nvim_create_autocmd("CursorHold", {
    group = group,
    callback = jump_to_latest,
  })
end

function M.stop()
  state.enabled = false
  state.root = nil
  state.files = {}
  vim.api.nvim_clear_autocmds({ group = group })
end

function M.setup()
  vim.api.nvim_create_user_command("Follow", function()
    M.start()
  end, {})

  vim.api.nvim_create_user_command("FollowStop", function()
    M.stop()
  end, {})
end

return M
