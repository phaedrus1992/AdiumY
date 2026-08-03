global HandyAdiumScripts

on run
	tell application "AdiumY"
		if not (exists service "AIM") then error
	end tell
end run