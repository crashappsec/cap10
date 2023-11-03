## :Author: John Viega (john@crashoverride.com)
## :Copyright: 2023, Crash Override, Inc.

import common, record, tables, nimutils, re, posix

type ExpectObject* = object
  captureFile*:  File
  capturePath*:  string
  captureState*: CaptureState
  patterns*:     OrderedTable[string, Regex]
  subproc*:      SubProcess
  exited*:       bool
  matchable*:    string
  pty_fd*:       cint

proc expectInput(ctx:     var ExpectObject,
                 unused:  pointer,
                 capture: cstring,
                 l:       int) {.cdecl.} =
  ctx.captureState.handleInput(unused, capture, l)

proc expectOutput(ctx:     var ExpectObject,
                  unused:  pointer,
                  capture: cstring,
                  l:       int) {.cdecl.} =
  if ctx.captureFile != nil:
    ctx.captureState.handleCapture(unused, capture, l)

  ctx.matchable &= binaryCStringToString(capture, l)

proc close*(ctx: var ExpectObject) {.cdecl.} =
  if not ctx.exited:
    discard ctx.pty_fd.close()

  if ctx.captureFile != nil:
    ctx.captureFile.close()
    ctx.captureFile = File(nil)

proc c10_close*(ctx: var ExpectObject) {.exportc, cdecl.} =
  ctx.close()

proc expect*(ctx: var ExpectObject, pattern = ""): string
    {.cdecl, discardable.} =
  if pattern == "" and ctx.patterns.len() == 0:
    ctx.patterns["default"]  = re(".")
  elif pattern != "":
    ctx.patterns["default"] = re(pattern)

  while ctx.exited == false:
    if ctx.subproc.poll():
      ctx.exited = true
      discard ctx.pty_fd.close()
      break

    var
      toMatch = cstring(ctx.matchable)
      l       = toMatch.len()

    for k, v in ctx.patterns:
      let (f, l) = toMatch.findBounds(v, 0, l)
      if f == -1:
        continue
      ctx.matchable = ctx.matchable[l .. ^1]
      ctx.patterns.clear()
      return k

  ctx.close()
  return "eof"

proc cap10_expect*(ctx: var ExpectObject, pattern: cstring): cstring {.
  exportc, cdecl .} =
  return cstring(ctx.expect($(pattern)))

proc addPattern*(ctx: var ExpectObject, text: string, tag: string) {.cdecl.} =
  ctx.patterns[tag] = re(text)

proc cap10_add_pattern*(ctx: var ExpectObject, text: cstring, tag: cstring)
    {.exportc, cdecl.} =
  ctx.addPattern($(text), $(tag))

proc send*(ctx: var ExpectObject, text: string, addCr = true)
    {.cdecl.} =
  var toWrite = if addCr: text & "\r" else: text
  ctx.pty_fd.rawFdWrite(addr toWrite[0], csize_t(toWrite.len()))
  discard ctx.subproc.poll()

proc cap10_send*(ctx: var ExpectObject, text: cstring, addCr = true)
    {.exportc, cdecl.} =
  ctx.send($text, addCr)

proc spawnSession*(ctx: var ExpectObject, cmd = "/bin/bash",
                    args = @["-i"], captureFile = "", passthrough = false)
    {.cdecl.} =
  var timeout: Timeval
  timeout.tv_sec  = Time(10000000)
  timeout.tv_usec = Suseconds(0)

  ctx = ExpectObject()

  if captureFile != "":
    (ctx.captureFile, ctx.capturePath) = captureFile.openWithoutClobber()

    if ctx.captureFile == nil:
      raise newException(IoError, "Cannot open capture file")

    ctx.captureState.captureSetup(ctx.captureFile.getFileHandle())


  ctx.subproc.initSubprocess(cmd, @[cmd] & args)
  ctx.subproc.setTimeout(timeout)
  ctx.subproc.usePty()
  ctx.subproc.setExtra(addr ctx)
  ctx.subproc.setPassthrough(SpIoAll, passthrough)

  if passthrough:
    ctx.subproc.setIoCallback(SpIoStdin, cast[SubProcCallback](expectInput))

  ctx.subproc.setIoCallback(SpIoStdout, cast[SubprocCallback](expectOutput))

  ctx.subproc.start()
  ctx.pty_fd = ctx.subproc.getPtyFd()

proc spawnSession*(cmd = "/bin/bash", args = @["-i"], captureFile = "",
                        passthrough = false): ExpectObject {.cdecl.} =
  result = ExpectObject()
  result.spawn_session(cmd, args, captureFile, passthrough)

proc cap10_spawn*(cmd: cstring, args: cStringArray, captureFile: cstring,
                  passthrough: bool): ExpectObject {.exportc, cdecl.} =
    var
      strargs: seq[string]
      i = 0
    while true:
      if args[i] == nil:
        break
      strargs.add($(args[i]))
      i += 1

    return spawnSession($(cmd), strargs, $(captureFile), passthrough)

when isMainModule:
  var
    s: ExpectObject

  s.spawnSession(captureFile = "expect.cap10", passthrough = true)
  s.expect(".*\\$ ")
  s.send("~/dev/chalk/chalk")
  s.expect("hiho\r")
  s.send("exit")
  s.expect("eof")
  echo "Capture saved to: ", s.capturePath
