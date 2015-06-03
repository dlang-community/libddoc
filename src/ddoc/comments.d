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
	import std.algorithm : find;
	import ddoc.macros : expand;
	import ddoc.highlight : highlight;

	auto sections = splitSections(text);
	string[string] sMacros = macros;
	auto m = sections.find!(p => p.name == "Macros");
	auto e = sections.find!(p => p.name == "Escapes");
	auto p = sections.find!(p => p.name == "Params");
	if (m.length) {
		if (!doMapping(m[0]))
			throw new DdocParseException("Unable to parse Key/Value pairs", m[0].content);
		foreach (kv; m[0].mapping)
			sMacros[kv[0]] = kv[1];
	}
	if (e.length) {
		assert(0, "Escapes not handled yet");
	}
	if (p.length) {
		if (!doMapping(p[0]))
			throw new DdocParseException("Unable to parse Key/Value pairs", m[0].content);
		foreach (ref kv; p[0].mapping)
			kv[1] = expand(Lexer(kv[1]), sMacros);
	}

	foreach (ref Section sec; sections) {
		if (sec.name != "Macros" && sec.name != "Escapes"
		    && sec.name != "Params")
			sec.content = expand(Lexer(highlight(sec.content)), sMacros);
	}
	return Comment(sections);
}

struct Comment
{
	bool isDitto() const @property
	{
		import std.string : strip, toLower;
		return sections.length == 2 && sections[0].content.strip().toLower() == "ditto";
	}
	Section[] sections;
}

unittest
{
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
	import std.string : format;
//	writeln(c.sections);
	assert(c.sections.length == 4, format("%d", c.sections.length));
	assert(c.sections[0].name is null);
	assert(c.sections[0].content == "Best-comment-ever © 2014", c.sections[0].content);
	assert(c.sections[1].name is null);
	assert(c.sections[2].name == "Params");
//	writeln(c.sections[2].mapping);
	assert(c.sections[2].mapping[0][0] == "a");
	assert(c.sections[2].mapping[0][1] == `<a href="param">`, c.sections[2].mapping[0][1]);
	assert(c.sections[3].name == "Returns");
}

unittest
{
	auto comment = `---
auto subcube(T...)(T values);
---
Creates a new cube in a similar way to whereCube, but allows the user to
define a new root for specific dimensions.`c;
	string[string] macros;
	Comment c = parseComment(comment, macros);
}

///
unittest {
	import std.conv : text;
	import ddoc.comments;

	auto s1 = `Stop the world

This function tells the Master to stop the world, taking effect immediately.

Params:
reason = Explanation to give to the $(B Master)
duration = Time for which the world $(UNUSED)would be stopped (as time itself stop, this is always $(F double.infinity))

---
void main() {
  import std.datetime : msecs;
  import master.universe.control;
  stopTheWorld("Too fast", 42.msecs);
  assert(0); // Will never be reached.
}
---

Returns:
Nothing, because nobody can restart it.

Macros:
F= $0`;

	auto expected = `<pre class="d_code"><font color=blue>void</font> main() {
  <font color=blue>import</font> std.datetime : msecs;
  <font color=blue>import</font> master.universe.control;
  stopTheWorld(<font color=red>"Too fast"</font>, 42.msecs);
  <font color=blue>assert</font>(0); <font color=green>// Will never be reached.</font>
}</pre>`;

	auto c = parseComment(s1, null);

	assert(c.sections.length == 6, text(c.sections.length));
	assert(c.sections[0].name is null, c.sections[0].name);
	assert(c.sections[0].content == "Stop the world", c.sections[0].content);

	assert(c.sections[1].name is null, c.sections[1].name);
	assert(c.sections[1].content == `This function tells the Master to stop the world, taking effect immediately.`,
	       c.sections[1].content);

	assert(c.sections[2].name == "Params", c.sections[2].name);
//	writeln(c.sections[2].mapping);
	assert(c.sections[2].mapping[0][0] == "reason", c.sections[2].mapping[0][0]);
	assert(c.sections[2].mapping[0][1] == "Explanation to give to the <b>Master</b>", c.sections[2].mapping[0][1]);
	assert(c.sections[2].mapping[1][0] == "duration", c.sections[2].mapping[0][1]);
	assert(c.sections[2].mapping[1][1] == "Time for which the world would be stopped (as time itself stop, this is always double.infinity)",
	       c.sections[2].mapping[1][1]);

	assert(c.sections[3].name == "Examples", c.sections[3].name);
	assert(c.sections[3].content == expected, c.sections[3].content);

	assert(c.sections[4].name == "Returns", c.sections[4].name);
	assert(c.sections[4].content == `Nothing, because nobody can restart it.`, c.sections[4].content);

	assert(c.sections[5].name == "Macros", c.sections[5].name);
	assert(c.sections[5].mapping[0][0] == "F", c.sections[5].mapping[0][0]);
	assert(c.sections[5].mapping[0][1] == "$0", c.sections[5].mapping[0][1]);
}

private:
bool doMapping(ref Section s) {
	import ddoc.macros : KeyValuePair, parseKeyValuePair;

	auto lex = Lexer(s.content);
	KeyValuePair[] pairs;
	if (parseKeyValuePair(lex, pairs)) {
		foreach (idx, kv; pairs)
			s.mapping ~= kv;
		return true;
	}
	return false;
}
