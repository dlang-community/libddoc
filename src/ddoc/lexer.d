/**
 * Copyright: © 2014 Economic Modeling Specialists, Intl.
 * Authors: Brian Schott
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt Boost License 1.0)
 */

module ddoc.lexer;

/**
 * DDoc token types.
 */
enum Type : ubyte
{
	/// $(LPAREN)
	lParen,
	/// $(RPAREN)
	rParen,
	/// $
	dollar,
	/// whitespace
	whitespace,
	/// newline
	newline,
	/// embedded D code
	embedded,
	/// ,
	comma,
	/// =
	equals,
	/// section header
	header,
	/// Anything else
	word,

}

/**
 * DDoc token
 */
struct Token
{
	string text;
	Type type;
}

/**
 * Lexer for DDoc comments.
 */
struct Lexer
{
	/**
	 * Params:
	 *     text = the _text to lex
	 */
	this(string text)
	{
		this.text = text;
		popFront();
	}

	bool empty() const @property
	{
		return _empty;
	}

	const(Token) front() const @property
	{
		return current;
	}

	void popFront()
	{
		if (offset >= text.length)
			_empty = true;
		while (offset < text.length) switch (text[offset])
		{
		case ',':
			current.text = text[offset .. offset + 1]; current.type = Type.comma; offset++; return;
		case '=':
			current.text = text[offset .. offset + 1]; current.type = Type.equals; offset++; return;
		case '$':
			current.text = text[offset .. offset + 1]; current.type = Type.dollar; offset++; return;
		case '(':
			current.text = text[offset .. offset + 1]; current.type = Type.lParen; offset++; return;
		case ')':
			current.text = text[offset .. offset + 1]; current.type = Type.rParen; offset++; return;
		case '\r':
			offset++;
			goto case;
		case '\n':
			current.text = text[offset .. offset + 1]; current.type = Type.newline; offset++; return;
		case '-':
			if (offset > 0 && text[offset - 1] == '\n' &&
				offset + 3 < text.length && text[offset .. offset + 3] == "---")
			{
				current.type = Type.embedded;
				// skip opening dashes
				while (offset < text.length && text[offset] == '-')
					offset++;
				if (offset < text.length && text[offset] == '\r')
					offset++;
				if (offset < text.length && text[offset] == '\n')
					offset++;
				size_t sliceBegin = offset;
				while (true)
				{
					if (offset >= text.length)
						break;
					if (text[offset] == '-' && offset > 0
						&& text[offset - 1] == '\n' && offset + 3 <= text.length
						&& text[offset .. offset + 3] == "---")
					{
						current.text = text[sliceBegin .. offset - 1];
						// skip closing dashes
						while (offset < text.length && text[offset] == '-')
							offset++;
						break;
					}
					else
						offset++;
				}
			}
			else
				offset++;
			return;
		case ' ':
		case '\t':
			size_t oldOffset = offset;
			while (offset < text.length && text[offset] == ' ' || text[offset] == '\t')
				offset++;
			current.type = Type.whitespace;
			current.text = text[oldOffset .. offset];
			return;
		default:
			lexWord();
			return;
		}
	}

	void lexWord()
	{
		import std.uni;
		import std.array;
		size_t oldOffset = offset;

		while (true)
		{
			offset++;
			if (offset >= text.length)
				break;
			dchar c = text[offset .. $].front;
			if (!(isAlpha(c) || isNumber(c)))
				break;
		}
		current.type = Type.word;
		current.text = text[oldOffset .. offset];
		if (((oldOffset > 0 && text[oldOffset - 1] == '\n') || oldOffset == 0)
			&& offset < text.length && text[offset] == ':')
		{
			current.type = Type.header;
			offset++;
		}
	}

	Token current;
	size_t offset;
	string text;
	bool _empty;
}

unittest
{
	import std.stdio;
	import std.algorithm;
	import std.range;
	auto expected = [
		Type.whitespace,
		Type.dollar,
		Type.lParen,
		Type.word,
		Type.whitespace,
		Type.word,
		Type.comma,
		Type.whitespace,
		Type.word,
		Type.rParen,
		Type.whitespace,
		Type.word,
		Type.whitespace,
		Type.word,
		Type.newline,
		Type.embedded,
	];
	Lexer l = Lexer(` $(D something, else) is *a
---
test
/** this is some test code */
assert (whatever);
---`c);
//	foreach (t; l)
//		writeln(t);
	assert (equal(l.map!(a => a.type), expected));
}
