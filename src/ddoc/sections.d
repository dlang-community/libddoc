/**
 * Copyright: © 2014 Economic Modeling Specialists, Intl.
 * Authors: Brian Schott
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt Boost License 1.0)
 */

module ddoc.sections;
import ddoc.lexer;
import ddoc.macros;

/**
 * Standard section names
 */
immutable string[] STANDARD_SECTIONS = [
	"Authors", "Bugs", "Copyright", "Date",
	"Deprecated", "Examples", "History", "License",
	"Returns", "See_also", "Standards", "Throws",
	"Version"
];

/**
 *
 */
struct Section
{
	/// The section name
	string name;

	/// The section content
	string content;

	/**
	 * Mapping used by the Params, Macros, and Escapes section types.
	 * "Params": key = parameter name, value = parameter description
	 * "Macros": key = macro name, value = macro implementation
	 * "Escapes": key = character to escape, value = replacement string
	 */
	string[string] mapping;

	/**
	 * Returns: true if $(D name) is one of $(D STANDARD_SECTIONS)
	 */
	bool isStandard() const @property
	{
		import std.algorithm;
		return STANDARD_SECTIONS.canFind(name);
	}

	///
	unittest
	{
		Section s;
		s.name = "Authors";
		assert (s.isStandard);
		s.name = "Butterflies";
		assert (!s.isStandard);
	}
}

Section parseMacrosOrParams(string name, ref Lexer lexer, ref string[string] macros)
{
	Section s;
	s.name = name;
	while (!lexer.empty && lexer.front.type != Type.header)
	{
		string[string] m;
		if (name != "Macros")
			m = macros;
		if (!parseKeyValuePair(lexer, s.mapping, m))
			break;
		if (name == "Macros")
		{
			foreach (k, v; s.mapping)
				macros[k] = v;
		}
	}
	return s;
}

/**
 * Returns: true if the parsing succeeded
 */
bool parseKeyValuePair(ref Lexer lexer, ref string[string] pairs, string[string] macros)
{
	import std.array;
//	import std.stdio;
	string key;
	while (!lexer.empty && (lexer.front.type == Type.whitespace
		|| lexer.front.type == Type.newline))
	{
		lexer.popFront();
	}
	if (!lexer.empty && lexer.front.type == Type.word)
	{
		key = lexer.front.text;
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
	if (lexer.front.type == Type.whitespace)
		lexer.popFront();
	auto app = appender!string();
	loop: while (!lexer.empty) switch (lexer.front.type)
	{
	case Type.newline:
		Lexer savePoint = lexer;
		while (!lexer.empty && lexer.front.type == Type.newline || lexer.front.type == Type.whitespace)
			lexer.popFront();
		if (lexer.front.type == Type.word)
		{
			string w = lexer.front.text;
			lexer.popFront();
			while (!lexer.empty && lexer.front.type == Type.whitespace)
				lexer.popFront();
			if (lexer.front.type == Type.equals)
			{
				lexer = savePoint;
				break loop;
			}
			else
			{
				app.put(" ");
				app.put(w);
			}
		}
		else
		{
			lexer.popFront();
			if (!lexer.empty)
				app.put(" ");
		}
		break;
	case Type.whitespace:
		app.put(" ");
		lexer.popFront();
		break;
	case Type.header:
		break loop;
	default:
		app.put(lexer.front.text);
		lexer.popFront();
//		break;
	}
	Lexer l = Lexer(app.data);
	pairs[key] = expandMacros(l, macros);
	return true;
}

/**
 * Parses a section.
 * Params:
 *     name = the section name
 *     lexer = the lexer
 *     macros = the macros used for
 *              substitution
 * Returns: the parsed section
 */
Section parseSection(string name, ref Lexer lexer, string[string] macros)
{
	import std.array;

	if (name == "Macros" || name == "Params" || name == "Escapes")
		return parseMacrosOrParams(name, lexer, macros);

	Section s;
	s.name = name;
	auto app = appender!string();
	loop: while (!lexer.empty) switch (lexer.front.type)
	{
	case Type.header:
		break loop;
	case Type.dollar:
		lexer.popFront();
		if (lexer.empty || lexer.front.type != Type.lParen)
		{
			app.put("$");
			break loop;
		}
		else
			app.put(expandMacro(lexer, macros));
		break;
	case Type.newline:
		lexer.popFront();
		app.put("\n");
		if (lexer.empty || (name == "Summary" && lexer.front.type == Type.newline))
			break loop;
		break;
	default:
		app.put(lexer.front.text);
		lexer.popFront();
		break;
	}
	s.content = app.data;
	return s;
}
