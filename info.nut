/*
 * This file is part of ServerGS, which is a GameScript for OpenTTD
 * Copyright (C) 2012-2013  Leif Linse
 *
 * ServerGS is free software; you can redistribute it and/or modify it 
 * under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 2 of the License
 *
 * ServerGS is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with ServerGS; If not, see <http://www.gnu.org/licenses/> or
 * write to the Free Software Foundation, Inc., 51 Franklin Street, 
 * Fifth Floor, Boston, MA 02110-1301 USA.
 *
 */

require("version.nut");

class FMainClass extends GSInfo {
	function GetAuthor()		{ return "Zuu"; }
	function GetName()			{ return "ServerGS"; }
	function GetDescription() 	{ return "This GS give admin port clients access to the GS API"; }
	function GetVersion()		{ return SELF_VERSION; }
	function GetDate()			{ return "2013-11-29"; }
	function CreateInstance()	{ return "MainClass"; }
	function GetShortName()		{ return "SeGS"; }
	function GetAPIVersion()	{ return "1.3"; }
	function GetURL()			{ return "http://www.tt-forums.net/viewtopic.php?f=65&t=68828"; }

	function GetSettings() {
		AddSetting({name = "show_error_dialogs",
				description = "Show API errors in a GUI dialog displayed for all companies (but not spectators)",
				easy_value = 0,
				medium_value = 0,
				hard_value = 0,
				custom_value = 0,
				flags = CONFIG_INGAME | CONFIG_BOOLEAN});

		AddSetting({name = "log_level", 
				description = "Debug: Log level (higher = print more)", 
				easy_value = 3,
				medium_value = 3,
				hard_value = 3,
				custom_value = 3,
				flags = CONFIG_INGAME, min_value = 1, max_value = 3});
		AddLabels("log_level", {_1 = "1: Info", _2 = "2: Verbose", _3 = "3: Debug" } );
	}
}

RegisterGS(FMainClass());
