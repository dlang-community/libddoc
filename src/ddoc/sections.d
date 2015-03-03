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
	"Returns", "See_Also", "Standards", "Throws",
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
 * Split a text into sections.
 *
 * Takes a text, which is generally a full comment (usually you'll also call
 * $(D unDecorateComment) before). It splits it in an array of $(D Section)
 * and returns it.
 * Whatever the content of $(D text) is, this function will always return an
 * array of at least 2 items. Those 2 sections are the "Summary" and "Description"
 * sections (which may be empty).
 *
 * Params:
 * text = A DDOC-formatted comment.
 *
 * Returns:
 * An array of $(D Section) with at least 2 elements.
 */
Section[] splitSections(string text) {
	import std.array : appender;

	/*
	 * Note: The specs says those sections are unnamed. So some people could
	 * name one of it's section 'Summary' or 'Description', and it would be
	 * legal (but arguably wrong).
	 */
	auto lex = Lexer(text);
	auto app = appender!(Section[]);
	bool hasSum, hasDesc;
	// Used to strip trailing newlines / whitespaces.
	size_t offset, end;
	string name;
	app ~= [ Section(), Section() ];
	// Strip leading whitespace
	//end = offset = lex.stripWhitespace();
	while (!lex.empty) switch (lex.front.type) {
	case Type.header:
		if (hasSum && hasDesc) {
			assert(name !is null);
			appendSection(name, lex.text[offset..end], app);
		}
		if (!hasSum) {
			hasSum = true;
			app.data[0].content = lex.text[offset..end];
			end = offset = lex.offset;
		}
		if (!hasDesc) {
			hasDesc = true;
			app.data[1].content = lex.text[offset..end];
			end = offset = lex.offset;
		}
		name = lex.front.text;
		lex.popFront();
		end = offset = lex.stripWhitespace();
		break;
	case Type.newline:
		lex.popFront();
		if (!hasSum && lex.front.type == Type.newline) {
			hasSum = true;
			app.data[0].content = lex.text[offset..end];
			end = offset = lex.offset;
			lex.popFront();
		}
		break;
	case Type.embedded:
		// If examples are contiguous to each others
		if (name != "Examples") {
			string prev = lex.text[offset..end];
			if (!hasSum) {
				app.data[0].content = prev;
				hasSum = hasDesc = true;
			} else if (!hasDesc) {
				hasDesc = true;
				app.data[0].content = prev;
			} else
				appendSection(name, prev, app);
			name = "Examples";
			auto tmp = Lexer(lex.text[end .. $]);
			offset = end + tmp.stripWhitespace();
			end = lex.offset;
		} else
			end = lex.offset;

		lex.popFront();
		break;
	default:
		end = lex.offset;
		lex.popFront();
		break;
	}

	if (name !is null)
		appendSection(name, lex.text[offset..end], app);

	return app.data;
}

unittest {
	import std.format : text;

	auto s1 = `Short comment.
Still comment.

Description.
Still desc...

Still

Authors:
Me & he
Bugs:
None
Copyright:
Date:

Deprecated:
Nope,

------
void foo() {}
----

History:
License:
Returns:
See_Also
See_Also:
Standards:

Throws:
Version:


`;
	auto cnt =
		[ "Short comment.\nStill comment.",
		  "Description.\nStill desc...\n\nStill",
		  "Me & he", "None", "", "", "Nope,",
		  "------\nvoid foo() {}\n----", "", "",
		  "See_Also", "", "", "", "" ];
	foreach (idx, sec; splitSections(s1)) {
		if (idx < 2) // Summary & description
			assert(sec.name is null, sec.name);
		else
			assert(sec.name == STANDARD_SECTIONS[idx-2], sec.name);
		assert(sec.content == cnt[idx],
		       text(sec.name, " (", idx, "): ", sec.content));
	}
}

private:
/// Append a section to the given output or merge it if a section with
/// the same name already exists.
///
/// Returns:
/// $(D true) if the section did not already exists,
/// $(D false) if the content was merged with an existing section.
bool appendSection(O)(string name, string content, ref O output) in {
	assert(name !is null, "You should not call appendSection with a null name");
} body {
	for (size_t i = 2; i < output.data.length; ++i) {
		if (output.data[i].name == name) {
			output.data[i].content ~= content;
			return false;
		}
	}
	output ~= Section(name, content);
	return true;
}
