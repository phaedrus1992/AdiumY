global HandyAdiumScripts

on run
	tell application "AdiumY"
		activate
	end tell
	tell application "System Events"
		if not (exists application process "AdiumY") then error
	end tell
end run