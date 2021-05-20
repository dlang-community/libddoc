/**
 * Converts embedded code sections to plain text inside `(D_CODE)` without any
 * syntax highlighting applied. This can be used as lightweight alternative to
 * ddoc.highlight when syntax highlighting the code is not actually needed.
 *
 * Copyright: © 2014 Economic Modeling Specialists, Intl.
 * Authors: Brian Schott, Mathias 'Geod24' Lang, Jan Jurzitza
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 */
module ddoc.unhighlight;

import std.array;

/**
 * Parses a string and replace embedded code (code between at least 3 '-') with
 * plaintext.
 *
 * Params:
 * str = A string that might contain embedded code. Only code will be modified.
 * 	If the string doesn't contain any embedded code, it will be returned as is.
 *
 * Returns:
 * A (possibly new) string containing the embedded code inside `D_CODE` macros.
 */
string unhighlight(string str)
{
	return highlightBase(str, (code, ref o) { o.put(code); });
}

/**
 * Base code for highlight and unhighlight, calling the $(LREF highlightCode)
 * callback parameter on all embedded sections to handle how it is emitted.
 *
 * Params:
 * str = A string that might contain embedded code. Only code will be modified.
 * 	If the string doesn't contain any embedded code, it will be returned as is.
 * highlightCode = The callback to call for embedded and inlined code sections.
 * 	`D_CODE` macross will be automatically prefixed and suffixed before/after
 * 	the call to this function.
 */
string highlightBase(string str, void delegate(string code, ref Appender!string output) highlightCode)
{
	import ddoc.lexer;
	import ddoc.macros : tokOffset;

	auto lex = Lexer(str, true);
	auto output = appender!string;
	size_t start;
	// We need this because there's no way to tell how many dashes precede
	// an embedded.
	size_t end;
	while (!lex.empty)
	{
		if (lex.front.type == Type.embedded)
		{
			if (start != end)
				output.put(lex.text[start .. end]);
			output.put("$(D_CODE ");
			highlightCode(lex.front.text, output);
			output.put(")");
			start = lex.offset;
		}
		else if (lex.front.type == Type.inlined)
		{
			if (start != end)
				output.put(lex.text[start .. end]);
			output.put("$(DDOC_BACKQUOTED ");
			highlightCode(lex.front.text, output);
			output.put(")");
			start = lex.offset;
		}
		end = lex.offset;
		lex.popFront();
	}

	if (start)
	{
		output.put(lex.text[start .. end]);
		return output.data;
	}
	else
	{
		return str;
	}
}

unittest
{
	import ddoc.lexer;
	import ddoc.macros;

	string[string] macros = null;

	string text = `description

Something else

---
// an example
---
Throws: a fit
---
/// another example
---`;
	text = unhighlight(text);
	auto lexer = Lexer(text, true);
	assert(expand(lexer, macros, false) == `description

Something else

<pre class="d_code">// an example</pre>
Throws: a fit
<pre class="d_code">/// another example</pre>`);
}
