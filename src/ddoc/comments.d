/**
 * Copyright: © 2014 Economic Modeling Specialists, Intl.
 * Authors: Brian Schott
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt Boost License 1.0)
 */

module ddoc.comments;
import ddoc.sections;
import ddoc.lexer;

Comment parseComment(string text, string[string] macros)
{
	Comment c;
	bool hasSummary;
	Lexer lexer = Lexer(text);
	while (!lexer.empty) switch (lexer.front.type)
	{
	case Type.header:
		string sectionName = lexer.front.text;
		lexer.popFront();
		c.sections ~= parseSection(sectionName, lexer, macros);
		break;
	case Type.whitespace:
	case Type.newline:
		lexer.popFront();
		break;
	default:
		if (hasSummary)
			c.sections ~= parseSection("Description", lexer, macros);
		else
		{
			c.sections ~= parseSection("Summary", lexer, macros);
			hasSummary = true;
		}
		break;
	}
	return c;
}

struct Comment
{
	bool isDitto() const @property
	{
		import std.string;
		return sections.length == 1 && sections[0].content.strip().toLower() == "ditto";
	}
	Section[] sections;
}

unittest
{
	import std.stdio;
	auto macros = ["A": "<a href=\"$0\">"];
	auto comment = `Best-comment-ever © 2014

I thought the same. I was considering writing it, actually.
Imagine how having the $(A tool) would have influenced the "final by
default" discussion. Amongst others, of course.

It essentially comes down to persistent compiler-as-a-library
issue. Tools like dscanner can help with some of more simple
transition cases but anything more complicated is likely to
require full semantic analysis.
Params:
	a = $(A param)
Returns:
	nothing of consequence
`;

	Comment c = parseComment(comment, macros);
//	writeln(c.sections.length);
//	foreach (s; c.sections)
//		writeln(s);
	import std.string;
//	writeln(c.sections);
	assert(c.sections.length == 4, format("%d", c.sections.length));
	assert(c.sections[0].name == "Summary");
	assert(c.sections[0].content == "Best-comment-ever © 2014", c.sections[0].content);
	assert(c.sections[1].name == "Description");
	assert(c.sections[2].name == "Params");
//	writeln(c.sections[2].mapping);
	assert(c.sections[2].mapping[0][0] == "a");
	assert(c.sections[2].mapping[0][1] == "<a href=\"param\">", c.sections[2].mapping[0][1]);
	assert(c.sections[3].name == "Returns");
}

unittest
{
	import std.stdio;
	auto comment = `---
auto subcube(T...)(T values);
---
Creates a new cube in a similar way to whereCube, but allows the user to
define a new root for specific dimensions.`c;
	string[string] macros;
	Comment c = parseComment(comment, macros);
//	foreach (s; c.sections)
//		writeln(s);
}
