# Cap10
## Script, capture and replay terminal sessions

You record and play back terminal sessions or other terminal programs
with the `cap10` command, which will record a process until it exits.

Cap10 will automatically remove long pauses in your input stream. So
type as slow as you want... walk away and come back an hour
later. You're good.

- `cap10 record [optional command]` starts recording.
- `cap10 play file.cap10`

Currently, there's no web player here, just the in-terminal
player. When you use modern terminals, you may not get awesome results
if you try to play back in a different terminal, since the underlying
codes sent are replayed.  More generic xterm stuff is going to be more
portable.

Note that this is not the same format file that asciinema uses. We
haven't looked at that yet; we use a binary format that's highly
efficient, allowing us to basically directly write what's recorded
directly as the terminal generates it. At some point soon we will
either generate their format at the end, or adapt an OSS web terminal
to use our format, whichever seems to make the most sense.

Additionally, on Linux, cap10 should build as a static ELF binary, so
can run in minimal environments like Alpine, without the Python
dependencies of asciinema.

## Expect More

You can also use `cap10` as an expect-like library, with the added
benefits:

1. You can fully capture your `expect` sessions if you want.
2. You can interact with your scripts if you want.

The second makes expect-like automation easier to write. I've had many
cases where the regexp didn't fire, and the result was a hanging
process, with a long iteration cycle to test. Here, you can just
manually enter input, which will generate output that runs through the
pattern matcher.

For example, the below code waits for a prompt, runs a command, then
waits for 'hiho' followed by the enter key (The enter key generates
'\r' NOT '\n').

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

It's early, and there are plenty of rough edges. This was done for our
internal use, but eventually we will polish this up. Until then, use
at your own risk :)

## Building

You need to have Nim 2.0 installed, and be on a 64-bit posix
system. We really develop only on Linux and Mac, so there's more than
a non-zero chance that *BSD or WSL won't work at this point...

But all you need to do to build the `cap10` binary is run from the
root of the repo:

```
nimble build
```
