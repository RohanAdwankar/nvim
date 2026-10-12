vim.opt.rtp:prepend(vim.fn.getcwd() .. "/plugins/diary.nvim")
local diary = require("diary")
diary.setup()
local api = vim.api
local requests = {}
vim.system = function(args, opts, done)
  local request = { prompt = opts.stdin, done = done }
  table.insert(requests, request)
  return { kill = function() request.cancelled = true end }
end

local function drain()
  vim.wait(250, function() return false end, 10)
end

local function lines(expected)
  assert(vim.deep_equal(api.nvim_buf_get_lines(0, 0, -1, false), expected),
    vim.inspect(api.nvim_buf_get_lines(0, 0, -1, false)))
end

local function complete(request, text)
  request.done({ code = 0, stdout = vim.json.encode({
    type = "item.completed", item = { type = "agent_message", text = text },
  }) .. "\n" })
  vim.wait(20, function() return false end)
end

local function fresh(text, tail)
  diary.stop(api.nvim_get_current_buf())
  vim.cmd("enew!")
  api.nvim_buf_set_lines(0, 0, -1, false, vim.list_extend({ "" }, tail or {}))
  api.nvim_win_set_cursor(0, { 1, 0 })
  requests = {}
  diary.toggle()
  drain()
  assert(#requests == 0)
  if text ~= "" then
    api.nvim_buf_set_text(0, 0, 0, 0, 0, { text })
    api.nvim_win_set_cursor(0, { 1, #text })
    drain()
  end
end

-- Enabling observes existing files without treating their contents as new input.
for _, row in ipairs({ 1, 2 }) do
  local path = vim.fn.tempname()
  local saved = { "stored note", "another stored note" }
  vim.fn.writefile(saved, path)
  vim.cmd("edit! " .. vim.fn.fnameescape(path))
  api.nvim_win_set_cursor(0, { row, 0 })
  requests = {}
  diary.toggle()
  drain()
  assert(#requests == 0, "enabling must not request a reply to existing content")
  lines(saved)
  assert(not vim.bo.modified)
  assert(vim.deep_equal(api.nvim_win_get_cursor(0), { row, 0 }))

  api.nvim_win_set_cursor(0, { 3 - row, 0 })
  api.nvim_exec_autocmds("CursorMovedI", {})
  vim.cmd("write")
  drain()
  assert(#requests == 0)
  lines(saved)

  api.nvim_buf_set_text(0, row - 1, 0, row - 1, 1, {})
  drain()
  assert(#requests == 0)
  diary.toggle()
  diary.toggle()
  drain()
  assert(#requests == 0)

  -- New writing replies beneath the edited line and preserves other file text.
  local expected = api.nvim_buf_get_lines(0, 0, -1, false)
  local col = #expected[row]
  expected[row] = expected[row] .. " plus new writing"
  api.nvim_win_set_cursor(0, { row, col })
  api.nvim_buf_set_text(0, row - 1, col, row - 1, col, { " plus new writing" })
  drain()
  assert(#requests == 1)
  complete(requests[1], "reply to new writing")
  table.insert(expected, row + 1, "")
  table.insert(expected, row + 2, "reply to new writing")
  lines(expected)
  diary.stop(api.nvim_get_current_buf())
  vim.fn.delete(path)
end

for _, entry in ipairs({ "hello", "what a day" }) do
  fresh(entry)
  assert(#requests == 1)
  complete(requests[1], "tell me more")
  lines({ entry, "", "tell me more" })

  -- Newlines extend the entry without overwriting the response.
  api.nvim_buf_set_text(0, 0, #entry, 0, #entry, { "", "next thought" })
  api.nvim_win_set_cursor(0, { 2, 12 })
  drain()
  lines({ entry, "next thought", "", "tell me more" })
  assert(#requests == 2)
  complete(requests[2], "go on\nI'm listening")
  lines({ entry, "next thought", "", "go on", "I'm listening" })

  -- Deletions cancel requests and cannot publish stale replies.
  api.nvim_buf_set_text(0, 1, 12, 1, 12, { "!" })
  drain()
  local pending = requests[#requests]
  local count = #requests
  api.nvim_buf_set_text(0, 1, 12, 1, 13, {})
  drain()
  assert(pending.cancelled and #requests == count)
  complete(pending, "stale reply")
  lines({ entry, "next thought", "", "go on", "I'm listening" })

  -- Removing the whole entry removes its reply and does not submit deletion.
  api.nvim_buf_set_lines(0, 0, 2, false, {})
  drain()
  lines({ "" })
  assert(#requests == count)
  api.nvim_buf_set_text(0, 0, 0, 0, 0, { "another entry" })
  drain()
  assert(#requests == count + 1)
  complete(requests[#requests], "another reply")
  lines({ "another entry", "", "another reply" })
end

fresh("one thought")
complete(requests[1], "response")
api.nvim_win_set_cursor(0, { 2, 0 })
api.nvim_exec_autocmds("CursorMovedI", {})
lines({ "one thought", "", "", "response" })
api.nvim_exec_autocmds("CursorMovedI", {})
lines({ "one thought", "", "", "response" })
api.nvim_buf_set_text(0, 1, 0, 1, 0, { "continued" })
drain()
assert(#requests == 2)
complete(requests[2], "updated")
lines({ "one thought", "continued", "", "updated" })

-- Editing a reply and saving do not trigger another response.
local count = #requests
api.nvim_buf_set_text(0, 3, 0, 3, 7, { "edited reply" })
api.nvim_exec_autocmds("BufWritePost", {})
drain()
assert(#requests == count)

fresh("a thought to erase")
complete(requests[1], "a reply to erase")
api.nvim_buf_set_lines(0, 0, 1, false, { "" })
drain()
assert(#requests == 1)
lines({ "" })

fresh("")
api.nvim_buf_set_text(0, 0, 0, 0, 0, { "pasted first", "pasted last" })
api.nvim_win_set_cursor(0, { 2, 11 })
drain()
assert(#requests == 1)
complete(requests[1], "paste reply")
lines({ "pasted first", "pasted last", "", "paste reply" })

-- Existing content is preserved, including when a new entry starts elsewhere.
fresh("first entry", { "", "existing text" })
complete(requests[1], "first reply")
api.nvim_buf_set_lines(0, 3, 4, false, { "last entry" })
api.nvim_win_set_cursor(0, { 4, 0 })
drain()
assert(#requests == 2)
complete(requests[2], "last reply")
lines({ "first entry", "", "first reply", "last entry", "", "last reply", "existing text" })
assert(requests[2].prompt:find("first entry", 1, true))
assert(requests[2].prompt:find("first reply", 1, true))

-- Disabling also cancels pending work.
api.nvim_buf_set_text(0, 3, 10, 3, 10, { "!" })
drain()
local pending = requests[#requests]
diary.toggle()
assert(pending.cancelled and not vim.b.diary)
complete(pending, "discard me")
lines({ "first entry", "", "first reply", "last entry!", "", "last reply", "existing text" })

-- A burst of typing submits the final text once; real dd cancels the entry.
fresh("")
api.nvim_feedkeys(api.nvim_replace_termcodes("ia fresh thought<Esc>", true, false, true), "xt", false)
drain()
assert(#requests == 1)
complete(requests[1], "a fresh reply")
lines({ "a fresh thought", "", "a fresh reply" })
api.nvim_feedkeys(api.nvim_replace_termcodes("A!<Esc>", true, false, true), "xt", false)
drain()
local undo_pending = requests[#requests]
assert(#requests == 2)
api.nvim_feedkeys("u", "xt", false)
drain()
assert(undo_pending.cancelled and #requests == 2)
complete(undo_pending, "stale after undo")
lines({ "a fresh thought", "", "a fresh reply" })
api.nvim_feedkeys("dd", "xt", false)
drain()
lines({ "" })
assert(#requests == 2)

-- A line replacement updates the same response rather than duplicating it.
fresh("original thought")
complete(requests[1], "original reply")
api.nvim_buf_set_lines(0, 0, 1, false, { "replacement thought" })
drain()
assert(#requests == 2)
complete(requests[2], "replacement reply")
lines({ "replacement thought", "", "replacement reply" })

-- Toggling twice does not leave an old listener controlling the new session.
diary.toggle()
diary.toggle()
api.nvim_buf_set_text(0, 0, 0, 0, 0, { "new " })
drain()
assert(vim.b.diary and #requests == 3)
diary.stop(api.nvim_get_current_buf())
print("diary tests passed")
