# ServerGS

Original Readme (to be updated for 2020 instructions)
```

==== ServerGS ====

Author: Zuu
License: GPL 2

Index:
  1. When is this script useful?
  2. How to use it
  2.1 Ping
  2.2 Call
  2.3 Call examples
  2.4 Events
  3. Available API methods
  4. Known issues


== 1. When is this script useful? ==

Use this game script on a server where you have set the admin port password 
and intend to use/write a program that via the Admin Port want to gain 
access to the Game Script API.

This script is not useful in single player games.


== 2. How to use it ==

Via the Admin Port it is possible to send JSON data to the Game Script.
For information on exactly how to do this see the Admin Port documentation.

You send a table with some fields. There are two general fields that any
request can contain:

action    Gives the action that you want to perform. Currently there is only
          two actions available: "ping" and "call".

number    Optional parameter containing an integer number giving the order
          number of your request. The response will carry a number field
          with the same number as in your request if this parameter is
          included in the request.


-- 2.1 The ping action --
The ping action is very simple:
{
    "action" = "ping",
    "number" = 0
}

As response, this will be sent:
{
    "result" = "ping",
    "number" = 0
}


-- 2.2 The call action --
The call action takes a few additional fields:

method    A string containing the name of the API method to call, including
          the class name. Separate class name and method using a single dot.
          For eg. GSTownList you omit the dot and just send "GSTownList".

          Example: "GSCompany.GetName"

args      An array containing the arguments to pass to the given API method.
          An argument can be an integer, a reference to an API symbol or a
          a literal string. Literal strings must begin and end with " or '.

          Example: [42, "GSGoal.BUTTON_OK", "\"A message from Admin\"",
          'other string']

companymode  If this optional field is given, it should contain an integer
          giving the company parameter to use when creating a GSCompanyMode
          that will be in the scope when the given API method is called.

          In the Game Script API there are some methods that require a
          GSCompanyMode to be in scope. This parameter allow you to
          fulfill this requirement.

testmode  If this optional field is given, a GSTestMode will be created
          and be in scope when the requested API method is called.


The response from the call action will contain these fields:

result    The return value from the API method.

error     If an error occur during the evaluation of your call, this field
          will be set to true. Otherwise it will be false.
          
          Note that this field is false if the API returns an error. It is
          only used to indicate errors in the data format of your request.

number    As described above, if your request contain the number field,
          the given number will be passed back in the response.


-- 2.3 Full examples of using the call action: --
Example: Charge 1000 money units from company 0 from the other expenses account
Send:
{
	"action": "call",
	"number": 5,
	"method": "GSCompany.ChangeBankBalance",
	"args": [0, -1000, "GSCompany.EXPENSES_OTHER"]
}

Response:
{
	"number": 5,
	"result": true,
	"error": false
}


Example: Test if the loan amount can be set to 10 000 money units
Send:
{
	"action": "call",
	"method": "GSCompany.SetLoanAmount",
	"companymode": 0,
	"testmode": 0,
	"args": [10000]
}

Response:
{
	"result": true,
	"error": false
}

Conclusion: Yes, the company has enough money on the bank to set the
bank balance to 10 000 money units. However, the loan was not changed
as testmode was used.


Example: Display a message with an OK and Cancel button
Send:
{
	"action": "call",
	"method": "GSGoal.Question",
	"args": [0, "GSCompany.COMPANY_INVALID", "\"Hello the admin is speaking\"", "GSGoal.QT_INFORMATION", "GSGoal.BUTTON_OK | GSGoal.BUTTON_CANCEL"]
}

Response:
{
	"result": true,
	"error": false
}

Note: You will not know if users pressed OK or Cancel, but this example
show how to join flags using the OR operator.


-- 2.4 Events --

Game Scripts can receive events from OpenTTD. There is not yet a
general support for all available events. However, the event that
occur when a client click on a button of a GSGoal.Question window
is sent on the Admin port:

All events contain these fields:

action    The action field is included to indicate that this
          message is not a response to a previous action sent to
          the Game Script.

          The action field will be set to "event" for all events.

event_type  This field will contain a string containing the name
          of the GSEventType enum corresponding to the event.
          

Event type ET_GOAL_QUESTION_ANSWER:

uniqueid  This field contain the uniqueid of the window that
          emitted the answer event.

button    This field contain the integer value of the pressed
          button (enum: GSGoal.QuestionButton)

company   This field contain the company id. Note that a company
          with multiple clients may emit more than one answer.



== 3. Available API methods ==

Almost all API methods documented at nogo.openttd.org are exposed
using ServerGS. A script was used to collect all API methods and
constants available in trunk. This means that new API methods added 
after this point are not added automatically. To do that the script
has to be re-ran and then a new version of ServerGS has to be
released.

In addition to the GS APIs these SuperLib methods are also exposed:
* Story.NewStoryPage
* Story.NewStoryPage2
* Story.ShowMessage
* Story.IsStoryBookAvailable

Documentation of these methods can be found here:
http://dev.openttdcoop.org/projects/superlib/repository/entry/story.nut

They are useful for constructing Story Book pages using just a single
JSON packet so that you don't have to ensure that the multiple API
calls required occur in the correct order also if there is some
network delay.


== 4. Known issues ==

* Starting/ending a literal string with " do not work in r25810
  because OpenTTD doesn't decode \" => " in the JSON => Squerrel
  parser. So until that is fixed, you need to begin/end literal
  strings with single quotes.

* You need at least r25809 nightly or 1.3.3 in order to be able 
  to call methods that take zero arguments.

* In order to receive messages back from the Game Script you need
  to set Admin Update Frequency to ADMIN_FREQUENCY_AUTOMATIC. This
  is not a bug in OpenTTD but more of a pitfall that is mentioned 
  here so that you don't forget to do this.
```
