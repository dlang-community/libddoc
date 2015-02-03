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

alias KeyValuePair = Tuple!(string, string);

immutable string[string] DEFAULT_MACROS;

shared static this()
{
	DEFAULT_MACROS =
		[
		 `B`: `<b>$0</b>`,
		 `I`: `<i>$0</i>`,
		 `U`: `<u>$0</u>`,
		 `P` : `<p>$0</p>`,
		 `DL` : `<dl>$0</dl>`,
		 `DT` : `<dt>$0</dt>`,
		 `DD` : `<dd>$0</dd>`,
		 `TABLE` : `<table>$0</table>`,
		 `TR` : `<tr>$0</tr>`,
		 `TH` : `<th>$0</th>`,
		 `TD` : `<td>$0</td>`,
		 `OL` : `<ol>$0</ol>`,
		 `UL` : `<ul>$0</ul>`,
		 `LI` : `<li>$0</li>`,
		 `LINK` : `<a href="$0">$0</a>`,
		 `LINK2` : `<a href="$1">$+</a>`,
		 `LPAREN` : `(`,
		 `RPAREN` : `)`,
		 `DOLLAR` : `$`,
		 `BACKTIP` : "`",
		 `DEPRECATED` : `$0`,

		 `RED` :   `<font color=red>$0</font>`,
		 `BLUE` :  `<font color=blue>$0</font>`,
		 `GREEN` : `<font color=green>$0</font>`,
		 `YELLOW` : `<font color=yellow>$0</font>`,
		 `BLACK` : `<font color=black>$0</font>`,
		 `WHITE` : `<font color=white>$0</font>`,

		 `D_CODE` : `<pre class="d_code">$0</pre>`,
		 `D_INLINECODE` : `<pre style="display:inline;" class="d_inline_code">$0</pre>`,
		 `D_COMMENT` : `$(GREEN $0)`,
		 `D_STRING`  : `$(RED $0)`,
		 `D_KEYWORD` : `$(BLUE $0)`,
		 `D_PSYMBOL` : `$(U $0)`,
		 `D_PARAM` : `$(I $0)`,

		 `DDOC` : `<html>
  <head>
    <META http-equiv="content-type" content="text/html; charset=utf-8">
    <title>$(TITLE)</title>
  </head>
  <body>
  <h1>$(TITLE)</h1>
  $(BODY)
  <hr>$(SMALL Page generated by $(LINK2 https://github.com/economicmodeling/libddoc, libddoc). $(COPYRIGHT))
  </body>
</html>`,

		 `DDOC_BACKQUOTED` : `$(D_INLINECODE $0)`,
		 `DDOC_COMMENT` : `<!-- $0 -->`,
		 `DDOC_DECL` : `$(DT $(BIG $0))`,
		 `DDOC_DECL_DD` : `$(DD $0)`,
		 `DDOC_DITTO` : `$(BR)$0`,
		 `DDOC_SECTIONS` : `$0`,
		 `DDOC_SUMMARY` : `$0$(BR)$(BR)`,
		 `DDOC_DESCRIPTION` : `$0$(BR)$(BR)`,
		 `DDOC_AUTHORS` : "$(B Authors:)$(BR)\n$0$(BR)$(BR)",
		 `DDOC_BUGS` : "$(RED BUGS:)$(BR)\n$0$(BR)$(BR)",
		 `DDOC_COPYRIGHT` : "$(B Copyright:)$(BR)\n$0$(BR)$(BR)",
		 `DDOC_DATE` : "$(B Date:)$(BR)\n$0$(BR)$(BR)",
		 `DDOC_DEPRECATED` : "$(RED Deprecated:)$(BR)\n$0$(BR)$(BR)",
		 `DDOC_EXAMPLES` : "$(B Examples:)$(BR)\n$0$(BR)$(BR)",
		 `DDOC_HISTORY` : "$(B History:)$(BR)\n$0$(BR)$(BR)",
		 `DDOC_LICENSE` : "$(B License:)$(BR)\n$0$(BR)$(BR)",
		 `DDOC_RETURNS` : "$(B Returns:)$(BR)\n$0$(BR)$(BR)",
		 `DDOC_SEE_ALSO` : "$(B See Also:)$(BR)\n$0$(BR)$(BR)",
		 `DDOC_STANDARDS` : "$(B Standards:)$(BR)\n$0$(BR)$(BR)",
		 `DDOC_THROWS` : "$(B Throws:)$(BR)\n$0$(BR)$(BR)",
		 `DDOC_VERSION` : "$(B Version:)$(BR)\n$0$(BR)$(BR)",
		 `DDOC_SECTION_H` : `$(B $0)$(BR)$(BR)`,
		 `DDOC_SECTION` : `$0$(BR)$(BR)`,
		 `DDOC_MEMBERS` : `$(DL $0)`,
		 `DDOC_MODULE_MEMBERS` : `$(DDOC_MEMBERS $0)`,
		 `DDOC_CLASS_MEMBERS` : `$(DDOC_MEMBERS $0)`,
		 `DDOC_STRUCT_MEMBERS` : `$(DDOC_MEMBERS $0)`,
		 `DDOC_ENUM_MEMBERS` : `$(DDOC_MEMBERS $0)`,
		 `DDOC_TEMPLATE_MEMBERS` : `$(DDOC_MEMBERS $0)`,
		 `DDOC_ENUM_BASETYPE` : `$0`,
		 `DDOC_PARAMS` : "$(B Params:)$(BR)\n$(TABLE $0)$(BR)",
		 `DDOC_PARAM_ROW` : `$(TR $0)`,
		 `DDOC_PARAM_ID` : `$(TD $0)`,
		 `DDOC_PARAM_DESC` : `$(TD $0)`,
		 `DDOC_BLANKLINE` : `$(BR)$(BR)`,

		 `DDOC_ANCHOR` : `<a name="$1"></a>`,
		 `DDOC_PSYMBOL` : `$(U $0)`,
		 `DDOC_PSUPER_SYMBOL` : `$(U $0)`,
		 `DDOC_KEYWORD` : `$(B $0)`,
		 `DDOC_PARAM` : `$(I $0)`,

		 `ESCAPES` : `/</&lt;/
/>/&gt;/
&/&amp;/`,
		 ];
}

/**
 * Expand  the macros present in the given lexer and write them to an $(D OutputRange).
 *
 * expandMacros takes a $(D ddoc.Lexer), and will, until it's empty, write it's expanded version to $(D output).
 *
 * Params:
 * input = A reference to the lexer to use. When expandMacros successfully returns, it will be empty.
 * macros = A list of DDOC macros to use for expansion. This override the previous definitions, hardwired in
 *		DDOC. Which means if an user provides a macro such as $(D macros["B"] = "<h1>$0</h1>";),
 *		it will be used, otherwise the default $(D macros["B"] = "<b>$0</b>";) will be used.
 *		To undefine hardwired macros, just set them to an empty string: $(D macros["B"] = "";).
 * output = An object satisfying $(D std.range.isOutputRange), usually a $(D std.array.Appender).
 */
void expandMacros(O)(ref Lexer input, string[string] macros, O output)
	if (isOutputRange!(O, string))
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

///
unittest {
	import ddoc.lexer;
	import std.array : appender;

	auto macros =
		[
		 // Note: You should NOT try to expand any recursive macro.
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
loop:	while (!input.empty) {
		switch (input.front.type) {
		case Type.dollar:
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
			break;
		case Type.comma:
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
			break;
		case Type.lParen:
			depth++;
			if (i < 10)
				currentApp.put(input.front.text);
			zeroApp.put(input.front.text);
			if (i > 1)
				plusApp.put(input.front.text);
			input.popFront();
			break;
		case Type.rParen:
			if (--depth == 0)
			{
				arguments[i] = currentApp.data;
				input.popFront();
				break loop;
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
			break;
		default:
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

/**
 * Parses macros declaration list, in the forms of 'NAME=VALUE'
 *
 * Returns: true if the parsing succeeded
 */
bool parseKeyValuePair(ref Lexer lexer, ref KeyValuePair[] pairs, string[string] macros, bool stopAtSection = true)
{
	import std.array : appender;
	import std.format : text;
	string prevKey, key;
	string prevValue, value;
	while (!lexer.empty) {
		// If parseAsKeyValuePair returns true, we stopped on a newline.
		// If it returns false, we're either on a section (header),
		// or the continuation of a macro.
		if (!parseAsKeyValuePair(lexer, key, value)) {
			if (prevKey == null) // First pass and invalid data
				return false;
			if (stopAtSection && lexer.front.type == Type.header)
				break;
			assert(lexer.offset >= prevValue.length);
			size_t start = lexer.offset - lexer.front.text.length
				- prevValue.length;
			while (!lexer.empty && lexer.front.type != Type.newline) {
				lexer.popFront();
			}
			prevValue = lexer.text[start..lexer.offset];
		} else {
			// New macro, we can save the previous one.
			// The only case when key would not be defined is
			if (prevKey)
				pairs ~= KeyValuePair(prevKey, prevValue);
			prevKey = key;
			prevValue = value;
			key = value = null;
		}
		if (!lexer.empty) {
			assert(lexer.front.type == Type.newline,
			       text("Front: ", lexer.front.type, ", text: ", lexer.text[lexer.offset..$]));
			lexer.popFront();
		}
	}

	if (prevKey)
		pairs ~= KeyValuePair(prevKey, prevValue);

	// Expand macros
	if (macros !is null) {
		foreach (ref kv; pairs) {
			auto l = Lexer(kv[1]);
			auto val = appender!string();
			expandMacros(l, macros, val);
			kv[1] = val.data;
		}
	}
	return true;
}

// Try to parse a line as a KeyValuePair, returns false if it fails
private bool parseAsKeyValuePair(ref Lexer olexer, ref string key, ref string value) {
	string _key;
	auto lexer = olexer;
	while (!lexer.empty && (lexer.front.type == Type.whitespace
				|| lexer.front.type == Type.newline))
		lexer.popFront();
	if (!lexer.empty && lexer.front.type == Type.word)
	{
		_key = lexer.front.text;
		lexer.popFront();
	}
	else
		return false;
	while (!lexer.empty && lexer.front.type == Type.whitespace)
		lexer.popFront();
	if (!lexer.empty && lexer.front.type == Type.equals)
		lexer.popFront();
	else
		return false;
	while (lexer.front.type == Type.whitespace)
		lexer.popFront();
	assert(lexer.offset > 0, "Something is wrong with the lexer");
	// Offset points to the END of the token, not the beginning.
	size_t start = lexer.offset - lexer.front.text.length;
	while (!lexer.empty && lexer.front.type != Type.newline) {
		assert(lexer.front.type != Type.header);
		lexer.popFront();
	}
	olexer = lexer;
	key = _key;
	size_t end = lexer.offset - ((start != lexer.offset) ? (1) : (0));
	value = lexer.text[start..end];
	return true;
}

/**
 * Parses macros files, usually with extension .ddoc.
 *
 * Macros files are files that only contains macros definitions.
 */
string[string] parseMacrosFile(string[] paths...) {
	import std.exception : enforce;
	import std.file : readText;
	import std.format : text;

	string[string] ret;
	foreach (file; paths) {
		KeyValuePair[] pairs;
		auto txt = readText(file);
		auto lexer = Lexer(txt);
		parseKeyValuePair(lexer, pairs, null, false);
		enforce(lexer.empty, text("Unparsed data (", lexer.offset, "): ",
					  lexer.text[lexer.offset..$]));
		foreach (kv; pairs)
			ret[kv[0]] = kv[1];
	}
	return ret;
}
