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
	lParen, /// $(LPAREN)
	rParen, /// $(RPAREN)
	dollar, /// $
	whitespace, /// whitespace
	newline, /// newline
	embedded, /// embedded D code
	inlined, /// backtick-inlined code
	comma, /// ,
	equals, /// =
	header, /// section header
	word, /// Anything else
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
	this(string text, bool skipHeader = false)
	{
		this.text = text;
		this.parseHeader = !skipHeader;
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
		import std.algorithm : startsWith;
		import std.array : appender;

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
				offset = inlineCode + 1;
			}
			return;
		case ',':
			current.text = text[offset .. offset + 1];
			current.type = Type.comma;
			offset++;
			return;
		case '=':
			current.text = text[offset .. offset + 1];
			current.type = Type.equals;
			offset++;
			return;
		case '$':
			current.text = text[offset .. offset + 1];
			current.type = Type.dollar;
			offset++;
			return;
		case '(':
			current.text = text[offset .. offset + 1];
			current.type = Type.lParen;
			offset++;
			return;
		case ')':
			current.text = text[offset .. offset + 1];
			current.type = Type.rParen;
			offset++;
			return;
		case '\r':
			offset++;
			goto case ;
		case '\n':
			current.text = text[offset .. offset + 1];
			current.type = Type.newline;
			offset++;
			return;
		case '-':
			if (prevIsNewline(offset, text) && text[offset .. $].startsWith("---"))
			{
				current.type = Type.embedded;
				// It's a string because user could mix spaces and tabs.
				string indent = getIndent(offset, text);
				// skip opening dashes
				while (offset < text.length && text[offset] == '-')
					offset++;
				if (offset < text.length && text[offset] == '\r')
					offset++;
				if (offset < text.length && text[offset] == '\n') {
					offset++;
					if (text.length > (offset + indent.length)
					    && text[offset .. offset + indent.length] == indent) {
						offset += indent.length;
					}
				}
				// Loops until we find the closing '---'.
				// Note that some more checking should be put into this to avoid
				// accidentally matching '---' sequences.
				// If 'indent' is 0, then we can just take a slice. However, in
				// most cases, there will be some indent, and we need to remove it
				// for the code to look nice.
				size_t sliceBegin = offset;
				auto app = appender!string;
				while (true)
				{
					if (offset >= text.length)
						throw new DdocException("Unterminated code block");
					if (indent && text[offset] == '\n')
					{
						app.put(text[sliceBegin .. ++offset]);
						sliceBegin = offset;
						// We need to check if the indentation is the same
						if (text[sliceBegin .. $].startsWith(indent)) {
							sliceBegin += indent.length;
							offset += indent.length;
						}
					}
					// Check for the end.
					else if (text[offset] == '-' && prevIsNewline(offset, text)
					    && text[offset .. $].startsWith("---"))
					{
						if (!indent)
							current.text = sliceBegin >= offset ? null : text[sliceBegin .. offset - 1];
						else {
							app.put(sliceBegin >= offset ? null : text[sliceBegin .. offset - 1]);
							current.text = app.data;
						}
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
			while (offset < text.length && (text[offset] == ' '
				|| text[offset] == '\t'))
				offset++;
			current.type = Type.whitespace;
			current.text = text[oldOffset .. offset];
			return;
		default:
			lexWord();
			return;
		}
	}

	//private:
	void lexWord()
	{
		import std.utf : decode;
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
		if (parseHeader && prevIsNewline(oldOffset, text) && offset < text.length
			&& text[offset] == ':')
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
			if (text[o .. $].startsWith("\r") || text[o .. $].startsWith("\n")
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
	bool parseHeader;
}

unittest
{
	import std.algorithm : map, equal;
	import std.array:array;

	auto expected = [Type.whitespace, Type.dollar, Type.lParen, Type.word,
		Type.whitespace, Type.word, Type.comma, Type.whitespace, Type.word,
		Type.rParen, Type.whitespace, Type.word, Type.whitespace, Type.word,
		Type.newline, Type.embedded, Type.newline, Type.header, Type.newline,
		Type.whitespace, Type.word, Type.whitespace, Type.equals, Type.whitespace,
		Type.dollar, Type.lParen, Type.word, Type.whitespace, Type.word,
		Type.rParen, Type.newline, Type.header, Type.newline, Type.whitespace,
		Type.word, Type.whitespace, Type.word, Type.whitespace, Type.word];
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
	assert(equal(l.map!(a => a.type), expected));

	auto expectedTexts2 = ["inlined code", " ", "identifier"];
	auto expectedTypes2 = [Type.inlined, Type.whitespace, Type.word];
	Lexer l2 = Lexer("`inlined code` identifier");
	auto tokens = l2.array();
	assert (equal(tokens.map!(a => a.type), expectedTypes2));
	assert (equal(tokens.map!(a => a.text), expectedTexts2));
}

/**
 * Class for library exception.
 *
 * Most often, this is thrown when a Ddoc document is misformatted
 * (unmatching parenthesis, too much arguments to a macro...).
 */
class DdocException : Exception
{
nothrow pure @safe:
	this(string msg, string file = __FILE__, size_t line = __LINE__,
		Throwable next = null)
	{
		super(msg, file, line, next);
	}

	// Allow method chaining:
	// throw new DdocException().snippet(lexer.text);
	@property DdocException snippet(string s)
	{
		m_snippet = s;
		return this;
	}

	@property string snippet() const
	{
		return m_snippet;
	}

	private string m_snippet;
}

class DdocParseException : DdocException
{
nothrow pure @safe:
	this(string msg, string code, string file = __FILE__, size_t line = __LINE__,
		Throwable next = null)
	{
		super(msg, file, line, next);
		this.snippet = code;
	}
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

/// Return the indentation present before the given offset.
/// offset should point past the indentation.
/// e.g. : '\t\ttest' => Offset should be 2 (the index of 't'),
///        and getIndent will return '\t\t'. If offset is 1,
///        getIndent returns '\t'.
string getIndent(size_t offset, string text) pure nothrow {
	// There's no indentation before.
	import std.stdio;
	// If the offset is 0, or there's no indentation before.
	if (offset < 1 || (text[offset - 1] != ' ' && text[offset - 1] != '\t'))
		return null;

	// At this point we already know that there's one level of indentation.
	size_t indent = 1;
	while (offset >= (indent + 1) // Avoid underflow
	       && (text[offset - indent - 1] == ' '
		   || text[offset - indent - 1] == '\t'))
		indent++;
	return text[offset - indent .. offset];
}

unittest {
	assert(" " == getIndent(1, "  test"));
	assert("  " == getIndent(2, "  test"));
	assert(!getIndent(3, "  test"));
	assert("\t \t" == getIndent(3, "\t \ttest"));
	assert("\t  " == getIndent(4, "\n\t  test"));
}
