module ddoc.types;

import ddoc.lexer;
import ddoc.sections;

struct Comment
{
	bool isDitto() const @property
	{
		import std.string : strip, toLower;

		return sections.length == 2 && sections[0].content.strip().toLower() == "ditto";
	}

	Section[] sections;

	/**
	 * Creates a Comment object without expanding the sections.
	 *
	 * Use $(LREF parse) with a function pointer to $(REF highlight, ddoc,highlight)
	 * or $(REF parseComment, ddoc,comments) to parse a comment while also
	 * expanding sections.
	 */
	static Comment parseUnexpanded(string text)
	{
		import ddoc.unhighlight : unhighlight;

		return parse(text, null, false, &unhighlight);
	}

	static Comment parse(string text, string[string] macros, bool removeUnknown,
		string function(string) highlightFn)
	{
		import std.functional : toDelegate;

		return parse(text, macros, removeUnknown, toDelegate(highlightFn));
	}

	static Comment parse(string text, string[string] macros, bool removeUnknown,
		string delegate(string) highlightFn)
	out(retVal)
	{
		assert(retVal.sections.length >= 2);
	}
	do
	{
		import std.algorithm : find;
		import ddoc.macros : expand;

		auto sections = splitSections(text);
		string[string] sMacros = macros;
		auto m = sections.find!(p => p.name == "Macros");
		const e = sections.find!(p => p.name == "Escapes");
		auto p = sections.find!(p => p.name == "Params");
		if (m.length)
		{
			if (!doMapping(m[0]))
				throw new DdocParseException("Unable to parse Key/Value pairs", m[0].content);
			foreach (kv; m[0].mapping)
				sMacros[kv[0]] = kv[1];
		}
		if (e.length)
		{
			assert(0, "Escapes not handled yet");
		}
		if (p.length)
		{
			if (!doMapping(p[0]))
				throw new DdocParseException("Unable to parse Key/Value pairs", p[0].content);
			foreach (ref kv; p[0].mapping)
				kv[1] = expand(Lexer(highlightFn(kv[1])), sMacros, removeUnknown);
		}

		foreach (ref Section sec; sections)
		{
			if (sec.name != "Macros" && sec.name != "Escapes" && sec.name != "Params")
				sec.content = expand(Lexer(highlightFn(sec.content)), sMacros, removeUnknown);
		}
		return Comment(sections);
	}
}

private:
bool doMapping(ref Section s)
{
	import ddoc.macros : KeyValuePair, parseKeyValuePair;

	auto lex = Lexer(s.content);
	KeyValuePair[] pairs;
	if (parseKeyValuePair(lex, pairs))
	{
		foreach (idx, kv; pairs)
			s.mapping ~= kv;
		return true;
	}
	return false;
}
