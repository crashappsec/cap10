# Cap10
## Script, capture and replay terminal sessions

You record and play back terminal sessions or other terminal programs
with the `cap10` command, which will record a process until it exits.

Cap10 will automatically remove long pauses in your input stream. So
type as slow as you want... walk away and come back an hour
later. You're good.

- `cap10 record [optional command]` starts recording.
- `cap10 play file.cap10`
- `cap10 convert [filename]` will convert a cap10 file to the _asciicast 2.0_ format.

The `cap10` capture format is binary, and there's currently not a web
player for it. But you can convert it to asciicast format.

On Linux, cap10 should build as a static ELF binary, so can run in
minimal environments like Alpine, without the Python dependencies of
asciinema.

Also, we produce a separate input log to make it easier to automate
scripting for demos (in conjunction w/ our expect capabilities
below). It captures keypresses only, so if you don't type out a full
command, it won't capture the exact commands (in the future we may do
some shell integration to get the shell view).

Essentially, cap10 should replace the following tools:

- script
- asciinema
- expect
- autoexpect (which never worked well anyway)

## Expect More

You can also use `cap10` as an expect-like library, with the added
benefits:

1. You can fully capture your `expect` sessions if you want.
2. You can interact with your scripts if you want.
3. You can capture the input from your interactions.

The second makes expect-like automation easier to write. I've had many
cases where the regexp didn't fire, and the result was a hanging
process, with a long iteration cycle to test. Here, you can just
manually enter input, which will generate output that runs through the
pattern matcher.

For example, the below code waits for a prompt, runs a command, then
waits for 'hiho' followed by the enter key (The enter key generates
'\r' NOT '\n'; the log file does translate them back to '\n' to be more
human readable).

But the code never does anything to send that string to the
terminal. Instead, you're left to manually interact with it, and when
the pattern is matched, the 'expect' call returns.

The `passthrough` flag specifies that the user should be able to
interact. At some point, we'll expose the ability to turn this on and
off at will, and to provide more control over tty settings. 

```
import cap10
var s: ExpectObject

s.spawnSession(captureFile = "expect.cap10", passthrough = true)
s.expect(".*\\$ ")
s.send("~/dev/chalk/chalk")
s.expect("hiho\r")
s.send("exit")
s.expect("eof")
echo "Capture saved to: ", s.capturePath
```

## The switchboard

At some point, we'll package this up as a library with bindings to
other languages.

Underlying everything is an IO multiplexing system that allows us to
abitrarily (and dynamically) route output from file descriptors to
other file descriptors, callbacks, etc, all without the need for
threads. We've got a bunch of little utilities we'd like to see on top
of this, that we may eventually add.

## Status

It's early, and there are some rough edges (for instance, if there are
file perms issues, we're currently not handling gracefully). This was
done for our internal use, but eventually we will polish this
up. Until then, use at your own risk :)

## Building

You need to have Nim 2.0 installed, and be on a 64-bit posix
system. We really develop only on Linux and Mac, so there's more than
a non-zero chance that *BSD or WSL won't work at this point...

But all you should need to do to build the `cap10` binary is run from
the root of the repo:

```
nimble build
```
