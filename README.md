# eotl_ttb - Ten Ton Brick Sound Bites

This is a TF2 sourcemod plugin.

It adds a say command that can play Ten Ton Brick sound bites.  This plugin is mostly the same as eotl_og, just stuff is renamed to be ttb.

By default users have this disabled

### Say Commands
<hr>

Running any of the following 3 say commands will enable ttb sound bites for the player

**!ttb**

plays a random ttb sound bite

**!ttb list**

Displays a lists of the ttb sound bites


**!ttb [shortname]**

plays [shortname] ttb sound bite


**!ttb disable**

This will disable ttb sound bites for the user


### Config File (addons/sourcemod/configs/eotl_ttb.cfg)
<hr>

This config file defines the ttb sound bites. Please refer to the config file for more detail on this.

### ConVars
<hr>

**eotl_ttb_max_player_plays [num]**

The number ot times a player can play a ttb sound bite per map

Default: 2

**eotl_ttb_min_time [seconds]**

The minimum amount of time that must pass before another ttb sound bite can be played.

Default: 10