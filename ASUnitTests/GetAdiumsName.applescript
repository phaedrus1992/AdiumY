global HandyAdiumScripts

on run
	tell application "AdiumY"
		if (get name) is not "AdiumY" then error
	end tell
end run