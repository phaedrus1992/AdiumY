global HandyAdiumScripts

on run
	tell application "AdiumY"
		if (get name of service "AIM") is not "AIM" then error
	end tell
end run