global HandyAdiumScripts

on run
	tell application "AdiumY"
		if (count services) is 0 then error
	end tell
end run