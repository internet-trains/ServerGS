/*
 * This file is part of MinimalGS, which is a GameScript for OpenTTD
 * Copyright (C) 2012  Leif Linse
 *
 * MinimalGS is free software; you can redistribute it and/or modify it 
 * under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 2 of the License
 *
 * MinimalGS is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with MinimalGS; If not, see <http://www.gnu.org/licenses/> or
 * write to the Free Software Foundation, Inc., 51 Franklin Street, 
 * Fifth Floor, Boston, MA 02110-1301 USA.
 *
 */

/** Import SuperLib for GameScript **/
import("util.superlib", "SuperLib", 36);
Log <- SuperLib.Log;
Helper <- SuperLib.Helper;
Story <- SuperLib.Story;

/** Import other source code files **/
require("version.nut"); // get SELF_VERSION
require("symbol_version.nut"); // get GetSymbolsFileName()
require(GetSymbolsFileName()); // get g_symbols
require("admin_port.nut"); // get AdminPort class

OWN_UNIQUEID <- 0;

class MainClass extends GSController 
{
	_loaded_data = null;
	_loaded_from_version = null;
	_init_done = null;

	/*
	 * This method is called when your GS is constructed.
	 * It is recommended to only do basic initialization of member variables
	 * here.
	 * Many API functions are unavailable from the constructor. Instead do
	 * or call most of your initialization code from MainClass::Init.
	 */
	constructor()
	{
		this._init_done = false;
	}
}

/*
 * This method is called by OpenTTD after the constructor, and after calling
 * Load() in case the game was loaded from a save game. You should never
 * return back from this method. (if you do, the script will crash)
 *
 * Start() contains of two main parts. First initialization (which is
 * located in Init), and then the main loop.
 */
function MainClass::Start()
{
	// Some OpenTTD versions are affected by a bug where all API methods
	// that create things in the game world during world generation will
	// return object id 0 even if the created object has a different ID. 
	// In that case, the easiest workaround is to delay Init until the 
	// game has started.
	if (Helper.HasWorldGenBug()) GSController.Sleep(1);

	if(!this.Init()) return;

	// Wait for the game to start (or more correctly, tell OpenTTD to not
	// execute our GS further in world generation)
	GSController.Sleep(1);

	// Game has now started and if it is a single player game,
	// company 0 exist and is the human company.

	// Warn if script is used in non-MP games
	if (!GSGame.IsMultiplayer()) {
		GSGoal.Question(OWN_UNIQUEID, GSCompany.COMPANY_INVALID, GSText(GSText.STR_NOT_MP_WARNING), GSGoal.QT_WARNING, GSGoal.BUTTON_OK);
		Log.Warning("The game is not a multiplayer game. The admin port control will therefor not function");
	}

	// Main Game Script loop
	while (true) {
		// Handle incoming messages from OpenTTD
		this.HandleEvents();

		// Sleep a bit (but not too long, so that incoming requests are
		// handled quickly)
		GSController.Sleep(10);
	}
}

/*
 * This method is called during the initialization of your Game Script.
 * As long as you never call Sleep() and the user got a new enough OpenTTD
 * version, all initialization happens while the world generation screen
 * is shown. This means that even in single player, company 0 doesn't yet
 * exist. The benefit of doing initialization in world gen is that commands
 * that alter the game world are much cheaper before the game starts.
 */
function MainClass::Init()
{
	if (this._loaded_data != null) {
		// Copy loaded data from this._loaded_data to this.*
		// or do whatever with the loaded data
	} else {
		// construct goals etc.
	}

	AdminPort.Initialize();

	// Indicate that all data structures has been initialized/restored.
	this._init_done = true;
	this._loaded_data = null; // the loaded data has no more use now after that _init_done is true.

	return true;
}

/*
 * This method handles incoming events from OpenTTD.
 */
function MainClass::HandleEvents()
{
	if(GSEventController.IsEventWaiting()) {
		local ev = GSEventController.GetNextEvent();
		if (ev == null) return;

		// Allow admin port to look at all events
		AdminPort.ReceiveEvent(ev);
	}
}

/*
 * This method is called by OpenTTD when an (auto)-save occurs. You should
 * return a table which can contain nested tables, arrays of integers,
 * strings and booleans. Null values can also be stored. Class instances and
 * floating point values cannot be stored by OpenTTD.
 */
function MainClass::Save()
{
	Log.Info("Saving data to savegame", Log.LVL_INFO);

	// In case (auto-)save happens before we have initialized all data,
	// save the raw _loaded_data if available or an empty table.
	if (!this._init_done) return this._loaded_data != null ? this._loaded_data : {};

	return { 
		some_data = null,
		//some_other_data = this._some_variable,
	};
}

/*
 * When a game is loaded, OpenTTD will call this method and pass you the
 * table that you sent to OpenTTD in Save().
 */
function MainClass::Load(version, tbl)
{
	Log.Info("Loading data from savegame made with version " + version + " of the game script", Log.LVL_INFO);

	// Store a copy of the table from the save game
	// but do not process the loaded data yet. Wait with that to Init
	// so that OpenTTD doesn't kick us for taking too long to load.
	this._loaded_data = {}
   	foreach(key, val in tbl) {
		this._loaded_data.rawset(key, val);
	}

	this._loaded_from_version = version;
}
