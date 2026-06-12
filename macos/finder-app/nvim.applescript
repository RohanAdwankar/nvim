on open inputItems
	set quotedPaths to ""
	repeat with inputItem in inputItems
		set quotedPaths to quotedPaths & " " & quoted form of POSIX path of inputItem
	end repeat
	my openInTerminal("/opt/homebrew/bin/nvim" & quotedPaths)
end open

on run
	my openInTerminal("/opt/homebrew/bin/nvim")
end run

on openInTerminal(nvimCommand)
	set launcher to "/tmp/nvim-finder-" & (do shell script "uuidgen") & ".command"
	set scriptText to "#!/bin/zsh" & linefeed & "export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin" & linefeed & "exec " & nvimCommand & linefeed
	do shell script "printf %s " & quoted form of scriptText & " > " & quoted form of launcher & "; chmod +x " & quoted form of launcher & "; open -a Terminal " & quoted form of launcher
end openInTerminal

