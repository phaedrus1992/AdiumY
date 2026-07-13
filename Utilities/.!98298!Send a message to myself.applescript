(*
Requirements:
* Adium 1.3 or later
* An AIM account

Installation:
Open this script in Script Editor and save it as a compiled script (.scpt) in ~/Library/Scripts. That script will then remember your username until the next time you open it in Script Editor.

Usage:
1. Create a chat with yourself on AIM. (The script would do this automatically, but this functionality is broken as of 1.3.2.)
2. Run the script. If it doesn't know your AIM username, it will ask for it. If you followed the instructions above, it will remember your username for future runs.
Once it knows your username, it will send a message to that username from that username.
*)

property aim_name : missing value

tell application "Adium"
	if aim_name = missing value then
		activate
		
		--If the user cancels, the script will simply end, so we don't need to handle that ourselves.
