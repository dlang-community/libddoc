#!/usr/bin/env rdmd

// Runs `dub test --compiler=$DC` with either the minimum available version on
// DUB or the maximum available version on dub, respecting the dub.json version
// range.
//
// Running with VERSION=min will use the lowest available version of a package,
// for a version specification of format
//   "~>0.13.0" this will run with "0.13.0",
//   ">=0.13.0" this will run with "0.13.0",
//   ">=0.13.0 <0.15.0" this will run with "0.13.0"
//   otherwise error.
//
// Running with VERSION=max will use the highest available version of a package,
// for a version specification of format
//   "~>0.13.0" this will run with "~>0.13.0",
//   ">=0.13.0" this will run with ">=0.13.0",
//   ">=0.13.0 <0.15.0" this will run with "<0.15.0"
//   otherwise error.
//
// By default this modifies the package "libdparse" but this can be modified by
// specifying the $PACKAGE environment variable.
//
// Temporarily creates a dub.json file and renames the original to dub.1.json,
// both of which is undone automatically on exit.
//
// dub upgrade will be run after creating the artificial dub.json and before
// running the test command.
//
// If you run with `-- <command>` then that command will be run instead of
// `dub test --compiler=$DC`
//
// The script returns 0 on success after all commands or 1 if anything fails.

import std;
import fs = std.file;

int main(string[] args)
{
	/// wanted target version (min or max)
	const ver = environment.get("VERSION", "max");
	/// package to modify and test
	const pkg = environment.get("PACKAGE", "libdparse");
	/// D compiler to use
	const dc = environment.get("DC", "dmd");

	if (!ver.among!("min", "max"))
	{
		stderr.writefln("Unsupported version '%s', try min or max instead", ver);
		return 1;
	}

	stderr.writeln("PACKAGE=", pkg);
	stderr.writeln("VERSION=", ver);
	stderr.writeln("DC=", dc);

	auto json = parseJSON(readText("dub.json"));
	auto verSpec = json["dependencies"][pkg];
	if (verSpec.type != JSONType.string)
	{
		stderr.writefln("Unsupported dub.json version '%s' (should be string)",
			verSpec);
		return 1;
	}

	// find the version range to use based on the dependency version and wanted
	// version target.
	string determined = resolveVersion(verSpec.str, ver);
	stderr.writefln("Testing using %s version %s.", pkg, determined);

	json["dependencies"][pkg] = JSONValue(determined);

	// backup dub.json to dub.1.json and restore on exit
	fs.rename("dub.json", "dub.1.json");
	scope (exit)
		fs.rename("dub.1.json", "dub.json");

	// create dummy dub.json and delete on exit
	fs.write("dub.json", json.toPrettyString);
	scope (exit)
		fs.remove("dub.json");

	stderr.writeln("$ dub upgrade");
	if (spawnShell("dub upgrade").wait != 0)
		return 1;

	auto cmd = ["dub", "test", "--compiler=" ~ dc];
	auto cmdIndex = args.countUntil("--");
	if (cmdIndex != -1)
		cmd = args[cmdIndex + 1 .. $];

	stderr.writefln("$ %(%s %)", cmd);
	if (spawnProcess(cmd).wait != 0)
		return 1;

	return 0;
}

string resolveVersion(string verRange, string wanted)
{
	if (verRange.startsWith("~>"))
	{
		switch (wanted)
		{
		case "min":
			return verRange[2 .. $];
		case "max":
			return verRange;
		default:
			assert(false, "unknown target version " ~ wanted);
		}
	}
	else if (verRange.startsWith(">="))
	{
		auto end = verRange.indexOf("<");
		if (end == -1)
		{
			switch (wanted)
			{
			case "min":
				return verRange[2 .. $];
			case "max":
				return verRange;
			default:
				assert(false, "unknown target version " ~ wanted);
			}
		}
		else
		{
			switch (wanted)
			{
			case "min":
				return verRange[2 .. end].strip;
			case "max":
				return verRange[end .. $];
			default:
				assert(false, "unknown target version " ~ wanted);
			}
		}
	}
	else
		throw new Exception("Unsupported version range specifier to multi-test:"
			~ verRange);
}
