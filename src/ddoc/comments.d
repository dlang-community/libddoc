/**
 * Copyright: © 2014 Economic Modeling Specialists, Intl.
 * Authors: Brian Schott
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt Boost License 1.0)
 */
module ddoc.comments;
import ddoc.sections;
import ddoc.lexer;

public import ddoc.types;

Comment parseComment(string text, string[string] macros, bool removeUnknown = true)
out(retVal)
{
	assert(retVal.sections.length >= 2);
}
do
{
	import ddoc.highlight : highlight;

	return Comment.parse(text, macros, removeUnknown, &highlight);
}

unittest
{
	// Issue #21
	Comment test = parseComment("\nParams:\n    dg = \n", null);
	assert(test.sections.length == 3);
	assert(test.sections[2].name == "Params");
}

unittest
{
	import std.conv : text;

	auto macros = ["A" : "<a href=\"$0\">"];
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
	import std.string : format;

	assert(c.sections.length == 4, format("%d", c.sections.length));
	assert(c.sections[0].name is null);
	assert(c.sections[0].content == "Best-comment-ever © 2014", c.sections[0].content);
	assert(c.sections[1].name is null);
	assert(c.sections[2].name == "Params");
	assert(c.sections[2].mapping[0][0] == "a");
	assert(c.sections[2].mapping[0][1] == `<a href="param">`, c.sections[2].mapping[0][1]);
	assert(c.sections[3].name == "Returns");
}

unittest
{
	auto macros = ["A" : "<a href=\"$0\">"];
	auto comment = `Best $(Unknown comment) ever`;

	Comment c = parseComment(comment, macros, true);

	assert(c.sections.length >= 1);
	assert(c.sections[0].name is null);
	assert(c.sections[0].content == "Best  ever", c.sections[0].content);
}

unittest
{
	auto macros = ["A" : "<a href=\"$0\">"];
	auto comment = `Best $(Unknown comment) ever`;

	Comment c = parseComment(comment, macros, false);

	assert(c.sections.length >= 1);
	assert(c.sections[0].name is null);
	assert(c.sections[0].content == "Best $(Unknown comment) ever", c.sections[0].content);
}

unittest
{
	auto comment = `---
auto subcube(T...)(T values);
---
Creates a new cube in a similar way to whereCube, but allows the user to
define a new root for specific dimensions.`c;
	string[string] macros;
	const Comment c = parseComment(comment, macros);
}

///
unittest
{
	import std.conv : text;

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

	immutable expected = `<pre class="d_code"><font color=blue>void</font> main() {
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
	assert(
		c.sections[1].content == `This function tells the Master to stop the world, taking effect immediately.`,
		c.sections[1].content);

	assert(c.sections[2].name == "Params", c.sections[2].name);
	//	writeln(c.sections[2].mapping);
	assert(c.sections[2].mapping[0][0] == "reason", c.sections[2].mapping[0][0]);
	assert(c.sections[2].mapping[0][1] == "Explanation to give to the <b>Master</b>",
		c.sections[2].mapping[0][1]);
	assert(c.sections[2].mapping[1][0] == "duration", c.sections[2].mapping[0][1]);
	assert(
		c.sections[2].mapping[1][1] == "Time for which the world would be stopped (as time itself stop, this is always double.infinity)",
		c.sections[2].mapping[1][1]);

	assert(c.sections[3].name == "Examples", c.sections[3].name);
	assert(c.sections[3].content == expected, c.sections[3].content);

	assert(c.sections[4].name == "Returns", c.sections[4].name);
	assert(c.sections[4].content == `Nothing, because nobody can restart it.`,
		c.sections[4].content);

	assert(c.sections[5].name == "Macros", c.sections[5].name);
	assert(c.sections[5].mapping[0][0] == "F", c.sections[5].mapping[0][0]);
	assert(c.sections[5].mapping[0][1] == "$0", c.sections[5].mapping[0][1]);
}

unittest
{
	import std.stdio : writeln, writefln;

	auto comment = `Unrolled Linked List.

Nodes are (by default) sized to fit within a 64-byte cache line. The number
of items stored per node can be read from the $(B nodeCapacity) field.
See_also: $(LINK http://en.wikipedia.org/wiki/Unrolled_linked_list)
Params:
	T = the element type
	supportGC = true to ensure that the GC scans the nodes of the unrolled
		list, false if you are sure that no references to GC-managed memory
		will be stored in this container.
	cacheLineSize = Nodes will be sized to fit within this number of bytes.`;

	auto parsed = parseComment(comment, null);
	assert(parsed.sections[3].name == "Params");
	assert(parsed.sections[3].mapping.length == 3);
	assert(parsed.sections[3].mapping[1][0] == "supportGC");
	assert(parsed.sections[3].mapping[1][1][0] == 't', "<<" ~ parsed.sections[3].mapping[1][1] ~ ">>");
}
