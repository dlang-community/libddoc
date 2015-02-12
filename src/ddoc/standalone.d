/**
 * Parser for standalone ".dd" files.
 *
 * See_Also: dlang.org/ddoc.html ("Using Ddoc for other Documentation" section).
 * Copyright: © 2014 Economic Modeling Specialists, Intl.
 * Authors: Mathias Lang
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt Boost License 1.0)
 */
module ddoc.standalone;

import std.stdio;

import ddoc.lexer;
import ddoc.sections;
import ddoc.macros;

string parseFile(string path, in string[string] context) {
	import std.conv : to;
	import std.datetime : Clock;
	import std.file : readText;
	import std.path : baseName, stripExtension;

	auto text = readText(path);
	// Predefined DDOC macros.
	// The user might want to provide his macros.
	// It makes sense for some (e.g. TITLE), not really for
	// DATETIME / YEAR, but the macros file are supposed to
	// override the predefinition, not the other way around.
	string[string] macros = context.aaDup;
	if (("TITLE" in macros) is null)
		macros["TITLE"] = baseName(path).stripExtension;
	if (("DATETIME" in macros) is null)
		macros["DATETIME"] = Clock.currTime.toSimpleString;
	if (("YEAR" in macros) is null)
		macros["YEAR"] = to!string(Clock.currTime.year);
	// parseDDString has to fill up COPYRIGHT
	if (("DOCFILENAME" in macros) is null) // FIXME ??
		macros["DOCFILENAME"] = path.stripExtension~".html";
	if (("SRCFILENAME" in macros) is null)
		macros["SRCFILENAME"] = baseName(path);

	macros["BODY"] = parseDDString(text, macros);
	return parseDdocBody(macros);
}

string parseDDString(string text, string[string] macros)
{
	import ddoc.highlight;
	import std.string : strip;
	import std.algorithm : startsWith;
	import std.array : appender;

	assert(text.startsWith("Ddoc"), "the string should start with 'Ddoc'");
	text = text[4 .. $];

	// The doc is between "Ddoc" (which must be at the beginning of the file)
	// and the "Macros" sections. So first we need to find the later.
	// Get macros and expand them.
	parseMacrosSection(text, macros);

	// Get the copyright section
	//auto copyright = getSection("Copyright", text, macros).content;
	//if (copyright !is null)
	//	macros["COPYRIGHT"] = copyright;
	text = highlight(text);
	auto lexer = Lexer(text, true);
	return expand(lexer, macros);
}

///
unittest {
	import std.stdio, std.string;

	auto text = `Ddoc
	This file is a standalone Ddoc file. It can contain any kind of
	$(MAC macros), defined in the $(MAC 'Macros:' section).

Macros:
	MAC=$0
	_=
`;

	auto expected = `This file is a standalone Ddoc file. It can contain any kind of
	macros, defined in the 'Macros:' section.`;

	auto lex = Lexer(text, true);
	// Whitespace and newline before / after not taken into account.
	auto res = parseDDString(text, null).strip;
	assert(res == expected, res);
}

// Warning: Does not support embedded code / inlining.
private string parseDdocBody(string[string] macros) {
	auto lexer = Lexer("$(DDOC)", true);
	return expandMacro(lexer, macros);
}

private void parseMacrosSection(ref string text, ref string[string] macros) {
	import std.string : indexOf;
	enum macSection = "\nMacros:\n";
	auto idx = text.indexOf(macSection);
	if (idx >= 0) {
		auto macroSection = text[idx + macSection.length .. $];
		KeyValuePair[] kvp;
		auto lex = Lexer(macroSection, true);
		assert(parseKeyValuePair(lex, kvp));
		foreach (kv; kvp) macros[kv[0]] = kv[1];
		text = text[0..idx];
	}
}

// BUG #14148
private auto aaDup(in string[string] aa) {
	string[string] ret;
	foreach (k, v; aa)
		ret[k] = v;
	return ret;
}

version (LIBDDOC_CONFIG_EXE):
int main(string[] args) {
	import std.algorithm;
	import std.getopt;
	import std.path;
	static import file = std.file;

	if (args.length == 1) {
		stderr.writeln(`Usage: `, args[0], ` [options] [macros.ddoc]* file.dd`);
		stderr.writeln();
		stderr.writeln(`Process standalone documentation files and write them to a file.`);
		stderr.writeln(`'.ddoc' files are macros definition file. Order matters.`);
		stderr.writeln();
		stderr.writeln(`Options:`);
		stderr.writeln(`-o|--output-file=path\tOutput a (single) parsed file to 'path';`);
		stderr.writeln(`-D|--output-dir=dir\tOutput all parsed file(s) to directory 'dir';`);
	}

	args = args[1..$];
	string outDir, outFile;
	getopt(args,
	       "output-dir|D", &outDir,
	       "output-file|o", &outFile
	       );
	auto ddocFiles = args.filter!((f) => f.extension == ".ddoc");

	if (!args.any!((f) => f.extension == ".dd")) {
		stderr.writeln("No .dd file provided");
		return 1;
	}

	bool oneFile;
	auto ctx = parseMacrosFile(ddocFiles);
	foreach (f; args) {
		if (f.extension == ".ddoc")
			continue;
		assert(f.extension == ".dd", "Don't know what to do with "~f);
		if (oneFile) {
			stderr.writeln("Only one .dd file allowed with o|output-file.");
			return 1;
		}
		oneFile = (outFile !is null);
		writeln("Processing file : ", f);
		auto data = parseFile(f, ctx);
		if (outFile !is null) {
			writeln("Writing ", data.length, " bytes to ", outFile);
			file.write(outFile, data);
		} else if (outDir !is null) {
			auto of = buildPath(outDir, baseName(f.setExtension(".html")));
			writeln("Writing ", data.length, " bytes to ", of);
			file.write(of, data);
		} else {
			auto of = baseName(f.setExtension(".html"));
			writeln("Writing ", data.length, " bytes to ", of);
			file.write(of, data);
		}
	}
	return 0;
}
