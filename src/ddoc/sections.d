/**
 * Copyright: © 2014 Economic Modeling Specialists, Intl.
 * Authors: Brian Schott
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt Boost License 1.0)
 */

module ddoc.sections;
import ddoc.lexer;
import ddoc.macros;
import std.typecons;

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
	 *
	 * $(UL
	 * $(LI "Params": key = parameter name, value = parameter description)
	 * $(LI "Macros": key = macro name, value = macro implementation)
	 * $(LI "Escapes": key = character to escape, value = replacement string)
	 * )
	 */
	KeyValuePair[] mapping;

	/**
	 * Returns: true if $(B name) is one of $(B STANDARD_SECTIONS)
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

/**
 * Parses a Macros or Params section, filling in the mapping field of the
 * returned section.
 */
Section parseMacrosOrParams(string name, ref Lexer lexer, ref string[string] macros)
{
	Section s;
	s.name = name;
	while (!lexer.empty && lexer.front.type != Type.header)
	{
		string[string] m;
		if (name != "Macros")
			m = macros;
		if (!parseKeyValuePair(lexer, s.mapping))
			break;
		if (name == "Macros")
		{
			foreach (kv; s.mapping)
				macros[kv[0]] = kv[1];
		}
	}
	return s;
}

/**
 * Parses a section.
 * Params:
 *     name = the section name
 *     lexer = the lexer
 *     macros = the macros used for substitution
 * Returns: the parsed section
 */
Section parseSection(string name, ref Lexer lexer, ref string[string] macros)
{
	import ddoc.macros : tokOffset;
	if (name == "Macros" || name == "Params" || name == "Escapes")
		return parseMacrosOrParams(name, lexer, macros);

	Section s;
	s.name = name;
	size_t start = tokOffset(lexer);
	size_t end = start;
	loop: while (!lexer.empty) switch (lexer.front.type)
	{
	case Type.header:
		break loop;
	case Type.newline:
		lexer.popFront();
		if (lexer.empty || (name == "Summary" && lexer.front.type == Type.newline))
		{
			lexer.popFront();
			break loop;
		}
		end = lexer.offset;
		break;
	default:
		end = lexer.offset;
		lexer.popFront();
		break;
	}
	s.content = lexer.text[start .. end];
	return s;
}
