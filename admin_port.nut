
class AdminPort
{
	constructor() {
		__DONT_CONSTRUCT_ME__();
	}

	// public static members:
	static function Initialize();
	static function ReceiveEvent(event);
}

/* static */ function AdminPort::Initialize()
{
	// g_symbols is imported from symbols.nut

	local n_symbols = 0;
	foreach(c in g_symbols) {
		foreach(m in c[1]) {
			n_symbols++;
		}
	}

	Log.Info(n_symbols + " API symbols (methods + constants) from OpenTTD " + g_symbols_version + " are exposed via the Admin Port", Log.LVL_INFO);

	// Add additional symbols for some SuperLib methods
	g_symbols.append(
		["Story", [
			["NewStoryPage", Story.NewStoryPage, null],
			["NewStoryPage2", Story.NewStoryPage2, null],
			["ShowMessage", Story.ShowMessage, null],
			["IsStoryBookAvailable", Story.IsStoryBookAvailable, null],
		]]
	);
}

/* static */ function AdminPort::ReceiveEvent(event)
{
	local ev_type = event.GetEventType();
	switch (ev_type) {
		/* Incoming message from Admin port */
		case GSEvent.ET_ADMIN_PORT: {
			local admin_event = GSEventAdminPort.Convert(event);
			local data = admin_event.GetObject();

			AdminPort.ReceiveAdminPortMessage(data);
			break;
		}

		/* If a button was pressed, send an event unless our own internal uniqueid was used. */
		case GSEvent.ET_GOAL_QUESTION_ANSWER: {
			local question_event = GSEventGoalQuestionAnswer.Convert(event);
			if (question_event.GetUniqueID() == OWN_UNIQUEID) break;
			local message = {
				action = "event",
				event_type = "ET_GOAL_QUESTION_ANSWER",
				unique_id = question_event.GetUniqueID(),
				company = question_event.GetCompany(),
				button = question_event.GetButton(),
			}
			GSAdmin.Send(message);
		}
		

		// other events ...
	}

}

/*
 * This method is called by the event handler when
 * an incoming message from the admin port has been
 * received.
 * @param data Squirrel object constructed from JSON data
 * @return void
 */
/* static */ function AdminPort::ReceiveAdminPortMessage(data) 
{
	if (data == null) throw APException("Received JSON data is null");
	if (typeof(data) != "table") throw APException("Received JSON root structure is not a table");
	if (!data.rawin("action")) throw APException("\"action\" field missing in the JSON table");

	// Create basic response table
	local response = {
		action=data.action,
		result=null
	}

	// Send back message number if given in data packet
	if (data.rawin("number")) response.number <- data.number;

	try {
		// Which action was requested?
		if (data.action == "call") {
			if (!data.rawin("method")) throw APException("\"method\" field missing in the JSON table");
			if (!data.rawin("args")) throw APException("\"args\" field missing in the JSON table");

			// If data.companymode exist, it give a company ID which should be used
			// to construct a GSCompanyMode in the scope where the requested method
			// will be called.
			local cm = null;
			if (data.rawin("companymode") && typeof(data.companymode) == "integer") {
				cm = GSCompanyMode(data.companymode);
			}

			// If data.testmode exist, create a GSTestMode instance.
			local tm = null;
			if (data.rawin("testmode")) {
				tm = GSTestMode();
			}

			response.result = AdminPort.Eval(data.method, data.args);

			// Log call + result
			local s = data.method + "(";
			local arg_str = "";
			foreach (arg in data.args) {
				if (arg_str != "") arg_str += ", ";
				arg_str += arg;
			}
			s += arg_str;
			s += ")";
			if (cm != null) s += " [company:" + data.companymode + "]";
			if (tm != null) s += " [testmode]";
			s += " => " + response.result;
			Log.Info(s, Log.LVL_SUB_DECISIONS);
		} else if (data.action == "ping") {
			response.result = "ping";
			Log.Info("Received a ping from admin port");
		} else {
			throw APException("Unknown action");
		}

		// Send response
		GSAdmin.Send(response);
	} catch(e) {
		Log.Info("--- to here ---", Log.LVL_INFO);
		Log.Warning("An error occurred while processing incoming Admin Port command due to unknown data format.", Log.LVL_INFO);
		response.error <- true;
		GSAdmin.Send(response);

		if (GSController.GetSetting("show_error_dialogs") == 1) {
			GSGoal.Question(OWN_UNIQUEID, GSCompany.COMPANY_INVALID, "" + e._str, GSGoal.QT_ERROR, GSGoal.BUTTON_OK);
		}
	}

}

/* static */ function AdminPort::Eval(call, args)
{
	local func = AdminPort.GetSymbol(call);
	local arg_values = [];
	local arg_num = 0; // argument number
	foreach(arg in args) {
		arg_num++;

		local arg_value = null;

		// Check type of argument string
		if (typeof(arg) == "string") {
			// A string can either be a literal string or a reference to an enum in the API
			local str = Trim(arg);
			if (str[0] == '"' || str[0] == "'"[0]) {
				// Literal string
				local end_char = str[0];
				if (str[str.len()-1] != end_char) throw APException("Unmatched " + end_char);
				arg_value = str.slice(1, str.len() - 1); // remove leading and terminating ".
			} else {
				// reference to API enum

				// Some enums are used as flags that can be joined using bitwise OR. Therefore
				// specifically support the OR operator. (but no other operator)
				local or_parts = Helper.SplitString("|", str);
				if (or_parts.len() == 0) {
					or_parts.append(str);
				}

				// Iterate over all referenced symbols and join their value using OR.
				arg_value = 0;
				foreach(or_part in or_parts) {
					local sym = AdminPort.GetSymbol(or_part);
					arg_value = arg_value | sym.symbol;
				}
			}
		} else if (typeof(arg) == "integer" || typeof(arg) == "boolean") {
			arg_value = arg;
		} else {
			throw APException("Unsupported argument type: " + typeof(arg) + " of argument \"" + arg_num + "\"");
		}
			
		arg_values.append(arg_value);
	}

	// Is there an argument definition available for this function?
	if (func.arg_def != null) {
		// Verify arg count
		if (arg_values.len() != func.arg_def.len()) throw APException("Wrong number of arguments to " + call + ". You passed " + arg_values.len() + " args, but it should be " + func.arg_def.len() + " arguments.");

		// Verify arg types
		for (local i = 0; i < arg_values.len(); i++) {
			local arg_type = typeof(arg_values[i]);
			local correct_type = null;

			if (func.arg_def[i] == 'i') correct_type = "integer";
			if (func.arg_def[i] == 'b') correct_type = "boolean";
			else if (func.arg_def[i] == 's') correct_type = "string";

			if (func.arg_def[i] != '.' && (correct_type == null || arg_type != correct_type)) {
				if (correct_type == null) correct_type = "[unknown type]";
				throw APException("Wrong argument type of argument " + (i+1) + " to " + call + ". Should be " + correct_type + " (" + func.arg_def[i] + ").");
			}
		}
	} else {
		Log.Info("No definition of how many arguments that " + call + " function can take", Log.LVL_DEBUG);
	}

	if (call == "GSGoal.Question" && arg_values[0] == OWN_UNIQUEID) {
		local warning1 = "You should not use the uniqueid " + OWN_UNIQUEID + " for GSGoal.Question because it is reserved for internal use (error dialogs like this one). ";
		local warning2 = "If you use the reserved uniqueid, you will not receive the button click event";
		if (GSController.GetSetting("show_error_dialogs") == 1) {
			GSGoal.Question(OWN_UNIQUEID, GSCompany.COMPANY_INVALID, warning1 + warning2, GSGoal.QT_WARNING, GSGoal.BUTTON_OK);
		}
		Log.Warning(warning1, Log.LVL_INFO);
		Log.Info(warning2, Log.LVL_INFO);
	}

	local result = Helper.CallFunction(func.symbol, arg_values);

	// If the result is an instance it is assumed to be a sub class of GSList and need to 
	// be converted to an Squirrel array so that it can be send back as JSON.
	if (typeof(result) == "instance") {
		Log.Info("Result is a class, try to convert it to an squirrel array", Log.LVL_DEBUG);
		local sq_array = [];
		foreach (val, _ in result) {
			sq_array.append(val);
		}
		result = sq_array;
	}

	return result;
}

function Trim(str) {
	// Trim start
	local pos = str.find(" ");
	while (pos == 0) {
		str = str.slice(1);
		pos = str.find(" ");
	}

	// Trim end
	pos = Helper.FindFromEnd(" ", str);
	while (pos == str.len() - 1) {
		str = str.slice(0, str.len() - 1);
		pos = Helper.FindFromEnd(" ", str);
	}

	return str;
}

/* static */ function AdminPort::GetSymbol(str) {
	local parts = Helper.SplitString(".", Trim(str));
	if (parts.len() == 1) {
		// In case a class constructor is called,
		// put the class name in the class slot and an empty
		// string in the member slot.
		parts = [str, ""];
	}

	local requested_class_name = parts[0];
	local requested_member_name = parts[1];

	if (parts.len() != 2) throw APException("Wrong number of dots (.) in symbol");

	// Use g_symbols from symbols.nut
	local class_list = g_symbols;

	local CLASS_NAME = 0;
	local CLASS_MEMBERS = 1;

	local MEMBER_NAME = 0;
	local MEMBER_SYMBOL = 1;
	local MEMBER_ARGS_DEF = 2;

	foreach(c in class_list) {
		if (c[CLASS_NAME] == requested_class_name) {
			local members = c[CLASS_MEMBERS];

			// Is class constructor symbol?
			if (requested_member_name == "") {
				// return first member, symbol value
				return {
					symbol = members[0][MEMBER_SYMBOL],
					arg_def = null,
				}
			} else {
				// find correct member
				foreach (member in members) {
					if (member[MEMBER_NAME] == requested_member_name) {
						return {
							symbol = member[MEMBER_SYMBOL],
							arg_def = member[MEMBER_ARGS_DEF],
						};
					}
				}

				throw APException("Unknown member of " + requested_class_name + " class: " + requested_member_name);
			}
		}
	}

	throw APException("Unknown class: " + requested_class_name);
}

// Private class
class APException
{
	_str = null;
	constructor(error_str) {
		this._str = error_str;
		Log.Warning("Error: " + error_str, Log.LVL_INFO);
		Log.Info("The debug log will below show a stack trace due to an exception being thrown", Log.LVL_INFO);
		Log.Info("--- Ignore from here ---", Log.LVL_INFO);
	}
}


