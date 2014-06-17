/**
 * Copyright: © 2014 Economic Modeling Specialists, Intl.
 * Authors: Brian Schott
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt Boost License 1.0)
 */

module ddoc.macros;

import ddoc.lexer;
import std.exception;
import std.range;

/+private immutable string[string] DEFAULT_MACROS;

shared static this()
{
	DEFAULT_MACROS["B"] = "<b>$0</b>";
	DEFAULT_MACROS["I"] = "<i>$0</i>";
	DEFAULT_MACROS["U"] = "<u>$0</u>";
	DEFAULT_MACROS["P"] = "<p>$0</p>";
	DEFAULT_MACROS["DL"] = "<dl>$0</dl>";
	DEFAULT_MACROS["DT"] = "<dt>$0</dt>";
	DEFAULT_MACROS["DD"] = "<dd>$0</dd>";
	DEFAULT_MACROS["TABLE"] = "<table>$0</table>";
	DEFAULT_MACROS["TR"] = "<tr>$0</tr>";
	DEFAULT_MACROS["TH"] = "<th>$0</th>";
	DEFAULT_MACROS["TD"] = "<td>$0</td>";
	DEFAULT_MACROS["OL"] = "<ol>$0</ol>";
	DEFAULT_MACROS["UL"] = "<ul>$0</ul>";
	DEFAULT_MACROS["LI"] = "<li>$0</li>";
	DEFAULT_MACROS["BIG"] = "<big>$0</big>";
	DEFAULT_MACROS["SMALL"] = "<small>$0</small>";
	DEFAULT_MACROS["BR"] = "<br/>";
	DEFAULT_MACROS["LINK"] = "<a href=\"$0\">$0</a>";
	DEFAULT_MACROS["LINK2"] = "<a href=\"$1\">$+</a>";
	DEFAULT_MACROS["LPAREN"] = "(";
	DEFAULT_MACROS["RPAREN"] = " )";
	DEFAULT_MACROS["DOLLAR"] = "$";
	DEFAULT_MACROS["DEPRECATED"] = "$0";
	DEFAULT_MACROS["RED"] = "<span style=\"color: red;\">$0</span>";
	DEFAULT_MACROS["BLUE"] = "<span style=\"color: blue;\">$0</span>";
	DEFAULT_MACROS["GREEN"] = "<span style=\"color: green;\">$0</span>";
	DEFAULT_MACROS["YELLOW"] = "<span style=\"color: yellow;\">$0</span>";
	DEFAULT_MACROS["BLACK"] = "<span style=\"color: black;\">$0</span>";
	DEFAULT_MACROS["WHITE"] = "<span style=\"color: white;\">$0</span>";
}+/

private immutable string[] MACRO_ARGUMENTS = [
	`\$0`, `\$1`, `\$2`, `\$3`, `\$4`, `\$5`, `\$6`, `\$7`, `\$8`, `\$9`, `\$\+`
];

string expandMacros(ref Lexer input, string[string] macros)
{
	auto app = appender!string();
	while (!input.empty)
	{
		if (input.front.type == Type.dollar)
		{
			Token t = input.front;
			input.popFront();
			if (input.empty || input.front.type != Type.lParen)
				app.put(t.text);
			else
				app.put(expandMacro(input, macros));
		}
		else
		{
			app.put(input.front.text);
			input.popFront();
		}
	}
	return cast(string) app.data;
}

string expandMacro(ref Lexer input, string[string] macros)
{
	import std.string;
	if (input.front.type == Type.dollar)
		input.popFront();
	enforce(input.front.type == Type.lParen);
	input.popFront();
	while (!input.empty && (input.front.type == Type.whitespace || input.front.type == Type.newline))
		input.popFront();
	enforce(input.front.type == Type.word, format("%s", input.front));
	string macroName = input.front.text;
	input.popFront();
	if (macroName !in macros)
		return "";
	if (input.front.type == Type.whitespace)
		input.popFront();
	string macroBody = *(macroName in macros);
	// [0] is "$0", [1] through [9] are "$1" through "$9", [10] is "$+"
	Appender!(string)[11] appenders;
	size_t i = 1;
	while (true)
	{
		if (input.front.type == Type.dollar)
		{
			Token t = input.front;
			input.popFront();
			if (input.empty || input.front.type !is Type.lParen)
			{
				appenders[0].put(t.text);
				appenders[i].put(t.text);
				if (i > 1)
					appenders[10].put(t.text);
				break;
			}
			else
			{
				import std.algorithm;
				string s = expandMacro(input, macros);
				if (s.canFind("$"))
				{
					auto l = Lexer(s);
					s = expandMacros(l, macros);
				}
				appenders[0].put(s);
				appenders[i].put(s);
				if (i > 1)
					appenders[10].put(s);
			}
		}
		else if (input.front.type == Type.comma)
		{
			i++;
			appenders[0].put(input.front.text);
			if (i > 2)
				appenders[10].put(input.front.text);
			input.popFront();
			if (!input.empty && input.front.type == Type.whitespace)
			{
				appenders[0].put(input.front.text);
				if (i > 2)
					appenders[10].put(input.front.text);
				input.popFront();
			}
		}
		else
		{
			appenders[0].put(input.front.text);
			appenders[i].put(input.front.text);
			if (i > 1)
				appenders[10].put(input.front.text);
			input.popFront();
		}
		if (input.empty || input.front.type == Type.rParen)
				break;

	}
	enforce(input.front.type == Type.rParen);
	input.popFront();
//	foreach (j, ref a; appenders)
//	{
//		import std.stdio;
//		if (j == 10)
//			writeln("$+: ", a.data);
//		else
//			writeln("$", j, ": ", a.data);
//	}
	string result = macroBody;
	foreach (j, arg; MACRO_ARGUMENTS)
	{
		import std.regex;
		string s = cast(string) appenders[j].data;
		result = result.replaceAll(regex(arg), s);
	}
	return result;
}

unittest
{
	import std.array;
	auto macros = ["D" : "<b>$0</b>", "P" : "<p>$(D $0)</p>", "KP" : "<b>$1</b><i>$+</i>"];
	auto l = Lexer(`$(D something $(KP a, b) $(P else), abcd)`c);
	auto expected = "<b>something <b>a</b><i>b</i> <p><b>else</b></p>, abcd</b>";
	string result = expandMacros(l, macros);
	assert (result == expected, result);
//	import std.stdio;
//	writeln(result);
}
