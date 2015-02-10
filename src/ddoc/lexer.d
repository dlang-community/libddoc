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
	/// backtick-inlined code
	inlined,
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
		case '`':
			offset++;
			immutable size_t inlineCode = inlineCodeIndex();
			if (inlineCode == size_t.max)
			{
				current.text = "`";
				current.type = Type.word;
			}
			else
			{
				current.text = text[offset .. inlineCode];
				current.type = Type.inlined;
				offset = inlineCode;
			}
			return;
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
			if (((offset > 0 && prevIsNewline(offset, text)) || offset == 0) &&
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
						&& prevIsNewline(offset, text) && offset + 3 <= text.length
						&& text[offset .. offset + 3] == "---")
					{
						current.text = sliceBegin >= offset ? null : text[sliceBegin .. offset - 1];
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
			{
				current.type = Type.word;
				current.text = "-";
				offset++;
			}
			return;
		case ' ':
		case '\t':
			size_t oldOffset = offset;
			while (offset < text.length && (text[offset] == ' ' || text[offset] == '\t'))
				offset++;
			current.type = Type.whitespace;
			current.text = text[oldOffset .. offset];
			return;
		default:
			lexWord();
			return;
		}
	}

private:

	void lexWord()
	{
		import std.utf:decode;
		import std.uni : isNumber, isAlpha;
		size_t oldOffset = offset;

		while (true)
		{
			text.decode(offset);
			if (offset >= text.length)
				break;
			size_t o = offset;
			dchar c = text.decode(o);
			if (!(isAlpha(c) || isNumber(c)) && c != '_')
				break;
		}
		current.type = Type.word;
		current.text = text[oldOffset .. offset];
		if (prevIsNewline(oldOffset, text) && offset < text.length && text[offset] == ':')
		{
			current.type = Type.header;
			offset++;
		}
	}

	size_t inlineCodeIndex() const
	{
		import std.algorithm : startsWith;
		size_t o = offset;
		while (o < text.length)
		{
			if (text[o .. $].startsWith("\r")
				|| text[o .. $].startsWith("\n")
				|| text[o .. $].startsWith("\u2028")
				|| text[o .. $].startsWith("\u2029"))
			{
				return size_t.max;
			}
			else if (text[o] == '`')
				return o;
			else
				o++;
		}
		return size_t.max;
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
		Type.newline,
		Type.header,
		Type.newline,
		Type.whitespace,
		Type.word,
		Type.whitespace,
		Type.equals,
		Type.whitespace,
		Type.dollar,
		Type.lParen,
		Type.word,
		Type.whitespace,
		Type.word,
		Type.rParen,
		Type.newline,
		Type.header,
		Type.newline,
		Type.whitespace,
		Type.word,
		Type.whitespace,
		Type.word,
		Type.whitespace,
		Type.word
	];
	Lexer l = Lexer(` $(D something, else) is *a
------------
test
/** this is some test code */
assert (whatever);
---------
Params:
	a = $(A param)
Returns:
	nothing of consequence`c);
//	foreach (t; l)
//		writeln(t);
	assert (equal(l.map!(a => a.type), expected));
}


bool prevIsNewline(size_t offset, immutable string text) pure nothrow
{
	if (offset == 0)
		return true;
	offset--;
	while (offset > 0 && (text[offset] == ' ' || text[offset] == '\t'))
		offset--;
	return text[offset] == '\n';
}
