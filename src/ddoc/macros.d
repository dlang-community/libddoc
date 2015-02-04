/**
 * Copyright: © 2014 Economic Modeling Specialists, Intl.
 * Authors: Brian Schott
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt Boost License 1.0)
 */

module ddoc.macros;

import ddoc.lexer;
import std.exception;
import std.range;
import std.algorithm;
import std.stdio;

immutable string[string] DEFAULT_MACROS;

shared static this()
{
	DEFAULT_MACROS["B"] = "<b>$0</b>";
	DEFAULT_MACROS["BIG"] = "<big>$0</big>";
	DEFAULT_MACROS["BLACK"] = "<span style=\"color: black;\">$0</span>";
	DEFAULT_MACROS["BLUE"] = "<span style=\"color: blue;\">$0</span>";
	DEFAULT_MACROS["BR"] = "<br/>";
	DEFAULT_MACROS["D_CODE"] = `<pre class="d_code">$0</pre>`;
	DEFAULT_MACROS["D_COMMENT"] = `$(GREEN $0)`;
	DEFAULT_MACROS["DD"] = "<dd>$0</dd>";
	DEFAULT_MACROS["DDOC_ANCHOR"]  = `<a name="$1"></a>`;
	DEFAULT_MACROS["DDOC_KEYWORD"] = `$(B $0)`;
	DEFAULT_MACROS["DDOC_PARAM"]   = `$(I $0)`;
	DEFAULT_MACROS["DDOC_PSYMBOL"] = `$(U $0)`;
	DEFAULT_MACROS["DEPRECATED"] = "$0";
	DEFAULT_MACROS["D_KEYWORD"] = `$(BLUE $0)`;
	DEFAULT_MACROS["DL"] = "<dl>$0</dl>";
	DEFAULT_MACROS["DOLLAR"] = "$";
	DEFAULT_MACROS["D_PARAM"] = `$(I $0)`;
	DEFAULT_MACROS["D_PSYMBOL"] = `$(U $0)`;
	DEFAULT_MACROS["D_STRING"] = `$(RED $0)`;
	DEFAULT_MACROS["DT"] = "<dt>$0</dt>";
	DEFAULT_MACROS["GREEN"] = "<span style=\"color: green;\">$0</span>";
	DEFAULT_MACROS["I"] = "<i>$0</i>";
	DEFAULT_MACROS["LI"] = "<li>$0</li>";
	DEFAULT_MACROS["LINK2"] = "<a href=\"$1\">$+</a>";
	DEFAULT_MACROS["LINK"] = "<a href=\"$0\">$0</a>";
	DEFAULT_MACROS["LPAREN"] = "(";
	DEFAULT_MACROS["OL"] = "<ol>$0</ol>";
	DEFAULT_MACROS["P"] = "<p>$0</p>";
	DEFAULT_MACROS["RED"] = "<span style=\"color: red;\">$0</span>";
	DEFAULT_MACROS["RPAREN"] = ")";
	DEFAULT_MACROS["SMALL"] = "<small>$0</small>";
	DEFAULT_MACROS["TABLE"] = "<table>$0</table>";
	DEFAULT_MACROS["TD"] = "<td>$0</td>";
	DEFAULT_MACROS["TH"] = "<th>$0</th>";
	DEFAULT_MACROS["TR"] = "<tr>$0</tr>";
	DEFAULT_MACROS["UL"] = "<ul>$0</ul>";
	DEFAULT_MACROS["U"] = "<u>$0</u>";
	DEFAULT_MACROS["WHITE"] = "<span style=\"color: white;\">$0</span>";
	DEFAULT_MACROS["YELLOW"] = "<span style=\"color: yellow;\">$0</span>";
}

void expandMacros(O)(ref Lexer input, string[string] macros, O output)
{
	while (!input.empty)
	{
		if (input.front.type == Type.dollar)
		{
			input.popFront();
			if (input.front.type == Type.lParen)
				output.put(expandMacro(input, macros));
			else
				output.put("$");
		}
		else
		{
			output.put(input.front.text);
			input.popFront();
		}
	}
}

/// Macros with arguments are expanded up to what's possible.
unittest {
	import ddoc.lexer;
	import std.array : appender;

	auto macros =
		[
		 "IDENTITY": "$0",
		 "HWORLD": "$(IDENTITY Hello world!)",
		 "ARGS": "$(IDENTITY $1 $+)",
		 "GREETINGS": "$(IDENTITY $(ARGS Hello, $0))",
		 ];
	foreach (k, ref v; macros) {
		auto lex = Lexer(v);
		auto app = appender!string();
		expandMacros(lex, macros, app);
		v = app.data;
	}
	
	assert(macros["IDENTITY"] == "$0", macros["IDENTITY"]);
	assert(macros["HWORLD"] == "Hello world!", macros["HWORLD"]);
	assert(macros["ARGS"] == "$1 $+", macros["ARGS"]);
	assert(macros["GREETINGS"] == "Hello $0", macros["GREETINGS"]);

	auto lex = Lexer(`$(B $(IDENTITY $(GREETINGS John Malkovich)))`);
	auto app = appender!string();
	expandMacros(lex, macros, app);
	auto result = app.data;
	assert(result == "<b>Hello John Malkovich</b>", result);
}

void collectMacroArguments(ref Lexer input, string[string] macros,
	ref string[11] arguments)
{
	size_t i = 1;
	auto zeroApp = appender!string();
	auto plusApp = appender!string();
	auto currentApp = appender!string();
	int depth = 1;
	while (!input.empty)
	{
		if (input.front.type == Type.dollar)
		{
			input.popFront();
			if (input.front.type == Type.lParen)
			{
				string s = expandMacro(input, macros);
				while (s.canFind("$("))
				{
					auto a = appender!string();
					Lexer l = Lexer(s);
					expandMacros(l, macros, a);
					s = a.data;
				}
				zeroApp.put(s);
				if (i < 10)
					currentApp.put(s);
				if (i > 1)
					plusApp.put(s);
				continue;
			}
			else
			{
				zeroApp.put("$");
				if (i < 10)
					currentApp.put("$");
				if (i > 1)
					plusApp.put("$");
			}
		}
		else if (input.front.type == Type.comma)
		{
			if (i < 9)
			{
				arguments[i] = currentApp.data;
				currentApp = appender!string();
				i++;
			}
			zeroApp.put(input.front.text);
			input.popFront();
			while (!input.empty && (input.front.type == Type.whitespace || input.front.type == Type.newline))
			{
				zeroApp.put(input.front.text);
				input.popFront();
			}
		}
		else if (input.front.type == Type.lParen)
		{
			depth++;
			if (i < 10)
				currentApp.put(input.front.text);
			zeroApp.put(input.front.text);
			if (i > 1)
				plusApp.put(input.front.text);
			input.popFront();
		}
		else if (input.front.type == Type.rParen)
		{
			if (--depth == 0)
			{
				arguments[i] = currentApp.data;
				input.popFront();
				break;
			}
			else
			{
				if (i < 10)
					currentApp.put(input.front.text);
				zeroApp.put(input.front.text);
				if (i > 1)
					plusApp.put(input.front.text);
				input.popFront();
			}
		}
		else
		{
			if (i < 10)
				putInApp(currentApp, input.front);
			putInApp(zeroApp, input.front);
			if (i > 1)
				putInApp(plusApp, input.front);
			input.popFront();
		}
	}
	arguments[0] = zeroApp.data;
	arguments[$ - 1] = plusApp.data;
}

void putInApp(App)(ref App app, Token token)
{
	if (token.type == Type.embedded)
	{
		app.put("<pre><code>");
		app.put(token.text);
		app.put("</code></pre>");
	}
	else
		app.put(token.text);
}

string expandMacro(ref Lexer input, string[string] macros)
{
	auto output = appender!string();
	if (input.front.type == Type.dollar)
		input.popFront();
	if (input.front.type != Type.lParen)
	{
		writeln("lparen expected");
		return "";
	}
	input.popFront();
	if (input.front.type != Type.word)
		return "";
	string macroName = input.front.text;
	input.popFront();
	while (!input.empty && (input.front.type == Type.whitespace || input.front.type == Type.newline))
		input.popFront();
	string[11] arguments;
	collectMacroArguments(input, macros, arguments);
	string macroValue;
	{
		const(string)* p = macroName in macros;
		if (p is null)
			if ((p = macroName in DEFAULT_MACROS) is null)
				return "";
		macroValue = *p;
	}
	if (macroValue.canFind("$("))
	{
		auto mv = appender!string();
		Lexer l = Lexer(macroValue);
		expandMacros(l, macros, mv);
		macroValue = mv.data;
	}
	for (size_t i = 0; i < macroValue.length; i++)
	{
		if (macroValue[i] == '$' && i + 1 < macroValue.length)
		{
			int c = macroValue[i + 1] - '0';
			if (c >= 0 && c < 10)
			{
				output.put(arguments[c]);
				i++;
			}
			else if (macroValue[i + 1] == '+')
			{
				output.put(arguments[$ - 1]);
				i++;
			}
			else
				output.put("$");
		}
		else
			output.put(macroValue[i]);
	}
	return output.data;
}


unittest
{
	import std.array;
	auto macros = [
		"D" : "<b>$0</b>",
		"P" : "<p>$(D $0)</p>",
		"KP" : "<b>$1</b><i>$+</i>",
		"LREF" : `<a href="#$1">$(D $1)</a>`];
	auto l = Lexer(`$(D something $(KP a, b) $(P else), abcd) $(LREF byLineAsync)`c);
	auto expected = `<b>something <b>a</b><i>b</i> <p><b>else</b></p>, abcd</b> <a href="#byLineAsync"><b>byLineAsync</b></a>`;
	auto result = appender!string();
	expandMacros(l, macros, result);
	assert (result.data == expected, result.data);
//	writeln(result.data);
}
