# diary.nvim

`:riddle` toggles Codex's GPT-6-Luna diary in the current buffer. Replies are editable
buffer text, included when you save the file. It responds after a 200 ms typing
pause, using low reasoning effort.

Enabling waits for new writing; existing file contents, cursor movement, saving,
and deletions do not start a reply.

The lowercase command expands to `:Riddle`, since Neovim requires user commands
to start with a capital letter.

The reply starts two lines below your entry. Pressing Enter or moving into the
blank line in insert mode keeps a blank line between your writing and the reply.
Deleting text cancels pending work without requesting another response. Removing
the whole entry also removes its reply. Typing elsewhere starts another entry;
previous exchanges remain in the buffer.

Requires Neovim 0.10+ and an authenticated `codex` executable with Luna access.
Only an enabled buffer's entries are sent to Codex. Requests run in an empty
temporary directory with user configuration disabled and a read-only sandbox.
