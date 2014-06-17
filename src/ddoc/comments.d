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
	Section[] sections;
}

unittest
{
	import std.stdio;
	auto macros = ["A": "<a href=\"$0\">"];
	auto comment = `This is some text

I thought the same. I was considering writing it, actually.
Imagine how having the $(A tool) would have influenced the "final by
default" discussion. Amongst others, of course.

It essentially comes down to persistent compiler-as-a-library
issue. Tools like dscanner can help with some of more simple
transition cases but anything more complicated is likely to
require full semantic analysis.
Params:
	a = $(A param)
`;

	Comment c = parseComment(comment, macros);
//	writeln(c.sections.length);
//	foreach (s; c.sections)
//		writeln(s);
	import std.string;
//	writeln(c.sections);
	assert(c.sections.length == 3, format("%d", c.sections.length));
	assert(c.sections[0].name == "Summary");
	assert(c.sections[1].name == "Description");
	assert(c.sections[2].name == "Params");
//	writeln(c.sections[2].mapping);
	assert("a" in c.sections[2].mapping);
	assert(c.sections[2].mapping["a"] == "<a href=\"param\">", c.sections[2].mapping["a"]);
}
