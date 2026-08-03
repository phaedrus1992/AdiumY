global HandyAdiumScripts

on run
	tell application "AdiumY"
		tell account (HandyAdiumScripts's defaultAccount)
			go offline
			if (get status type) is not offline then error
			go online
			if (get status type) is not available then error
		end tell
	end tell
end run