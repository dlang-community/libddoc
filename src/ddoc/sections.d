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
immutable string[] STANDARD_SECTIONS = ["Authors", "Bugs", "Copyright", "Date",
	"Deprecated", "Examples", "History", "License", "Returns", "See_Also",
	"Standards", "Throws", "Version"];
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
		import std.algorithm : canFind;

		return STANDARD_SECTIONS.canFind(name);
	}

	///
	unittest
	{
		Section s;
		s.name = "Authors";
		assert(s.isStandard);
		s.name = "Butterflies";
		assert(!s.isStandard);
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
Section[] splitSections(string text)
{
	import std.array : appender;
	import std.string : strip;

	// Note: The specs says those sections are unnamed. So some people could
	// name one of it's section 'Summary' or 'Description', and it would be
	// legal (but arguably wrong).
	auto lex = Lexer(text);
	auto app = appender!(Section[]);
	bool hasSummary;
	// Used to strip trailing newlines / whitespace.
	lex.stripWhitespace();
	size_t sliceStart = lex.offset - lex.front.text.length;
	size_t sliceEnd = sliceStart;
	string name;
	app ~= Section();
	app ~= Section();

	void finishSection()
	{
		import std.algorithm.searching : canFind, endsWith, find;
		import std.range : dropBack, enumerate, retro;

		auto text = lex.text[sliceStart .. sliceEnd];
		// remove the last line from the current section except for the last section
		// (the last section doesn't have a following section)
		if (text.canFind("\n") && sliceEnd != lex.text.length && !text.endsWith("---"))
			text = text.dropBack(text.retro.enumerate.find!(e => e.value == '\n').front.index);

		if (!hasSummary)
		{
			hasSummary = true;
			app.data[0].content = text;
		}
		else if (name is null)
		{
			//immutable bool hadContent = app.data[1].content.length > 0;
			app.data[1].content ~= text;
		}
		else
		{
			appendSection(name, text, app);
		}
		sliceStart = sliceEnd = lex.offset;
	}

	while (!lex.empty) switch (lex.front.type)
	{
	case Type.header:
		finishSection();
		name = lex.front.text;
		lex.popFront();
		lex.stripWhitespace();
		break;
	case Type.newline:
		lex.popFront();
		if (name is null && !lex.empty && lex.front.type == Type.newline)
			finishSection();
		break;
	case Type.embedded:
		finishSection();
		name = "Examples";
		appendSection("Examples", "---\n" ~ lex.front.text ~ "\n---", app);
		lex.popFront();
		sliceStart = sliceEnd = lex.offset;
		break;
	default:
		lex.popFront();
		sliceEnd = lex.offset;
		break;
	}
	finishSection();
	foreach (ref section; app.data)
		section.content = section.content.strip();
	return app.data;
}

unittest
{
	import std.conv : text;
	import std.algorithm.iteration : map;
	import std.algorithm.comparison : equal;

	auto s = `description

Something else

---
// an example
---
Throws: a fit
---
/// another example
---
`;
	const sections = splitSections(s);
	immutable expectedExample = `---
// an example
---
---
/// another example
---`;
	assert(sections.length == 4, text(sections));
	assert(sections.map!(a => a.name).equal(["", "", "Examples", "Throws"]),
		text(sections.map!(a => a.name)));
	assert(sections[0].content == "description", text(sections));
	assert(sections[1].content == "Something else", text(sections));
	assert(sections[2].content == expectedExample, sections[2].content);
	assert(sections[3].content == "a fit", text(sections));
}

unittest
{
	import std.conv : text;

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
	auto cnt = ["Short comment.\nStill comment.",
		"Description.\nStill desc...\nStill", "Me & he", "None", "", "", "Nope,",
		"---\nvoid foo() {}\n---", "", "", "See_Also", "", "", "", ""];
	foreach (idx, sec; splitSections(s1))
	{
		if (idx < 2)
			// Summary & description
			assert(sec.name is null, sec.name);
		else
			assert(sec.name == STANDARD_SECTIONS[idx - 2], sec.name);
		assert(sec.content == cnt[idx], text(sec.name, " (", idx, "): ",
			sec.content));
	}
}

// Issue 23
unittest
{
	immutable comment = `summary

---
some code!!!
---`;
	const sections = splitSections(comment);
	assert(sections[0].content == "summary");
	assert(sections[1].content == "");
	assert(sections[2].content == "---\nsome code!!!\n---");
}

// Split section content correctly (without next line)
unittest
{
	immutable comment = `Params:
    pattern(s) = Regular expression(s) to match
    flags = The _attributes (g, i, m and x accepted)

    Throws: $(D RegexException) if there were any errors during compilation.`;

    const sections = splitSections(comment);
	assert(sections[2].content == "pattern(s) = Regular expression(s) to match\n" ~
			"    flags = The _attributes (g, i, m and x accepted)");
}

private:
/**
 * Append a section to the given output or merge it if a section with
 *
 * the same name already exists.
 *
 * Returns:
 * $(D true) if the section did not already exists,
 * $(D false) if the content was merged with an existing section.
 */
bool appendSection(O)(string name, string content, ref O output)
in
{
	assert(name!is null, "You should not call appendSection with a null name");
}
body
{
	for (size_t i = 2; i < output.data.length; ++i)
	{
		if (output.data[i].name == name)
		{
			if (output.data[i].content.length == 0)
				output.data[i].content = content;
			else if (content.length > 0)
				output.data[i].content ~= "\n" ~ content;
			return false;
		}
	}
	output ~= Section(name, content);
	return true;
}
