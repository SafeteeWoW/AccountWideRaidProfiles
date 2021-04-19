## AccountWideRaidProfiles

**World of Warcraft addon that enables cross character profile management for
the default blizzard raid frame profiles.**

-----------------------------

Automatically stores the raid profile options, the raid frame position, and the
changes to them locally in the addon profile.

Choose the same profiles for different characters if you want them to share the
same blizzard raid profile.

You can precisely adjust the position and size of the raid frame by entering
numbers in the option panel.

If two characters share the same addon profile and you change the raid frame in
one character, when you log into the other character, the addon requests to reload ui.
The addon also requests for reloading the user interface when changing addon profiles or
changing the frame through the addon. This is to avoid taint, which makes raid frame
unclickable due to Blizzard restrictions.

"/awrp" command to show command line options.
"Menu"->"Interface"->"Addons"->"AccountWideRaidProfiles" to show option GUI.

If this addon has lua error,
frame taint issue(frame unclickable or "Interface failed due to an addon" error message in chat),
or making raid frame incorrectly displayed or any other bugs, put comment on Github.

Please give an easy way to reproduce the bug. I do not play WoW much at the moment.

If the frame is not correctly shown after you disable the addon (due to possible bug in this addon),
goto "Interface" ->"Raid Profiles" -> click "Reset Position" to reset settings.
(Alternatively, enable the addon and then in the "Account Wide Raid Profile" addon panel, click "Reset Profile",
then disable the addon)

------------------------------

If you want to synchronize other settings of Blizzard UI across characters, complete quit the game,
copy and paste the file controlling the setting in
"World of Warcraft\WTF\Account\Number#Number\SERVER_NAME\CHARACTER_Name" to the other character's folder.
For example, if you want to sync chat setting, the file is "chat-cache.txt"

I create this addon because Raid Profiles Setting is one of the few settings stored on the server,
as of when I wrote the addon, and cannot be synchronized in that way.