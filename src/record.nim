## :Author: John Viega (john@crashoverride.com)
## :Copyright: 2023, Crash Override, Inc.

import nimutils, terminal, common, std/tempfiles, os, json, posix, strutils

{.emit: """
extern ssize_t read_one(int, char *, size_t);
extern bool write_data(int, char *, size_t);
""".}

proc getLoginShell*(): string =
  result = $(getpwuid(geteuid())[].pw_shell)

# Changing the raw file format to go ahead and use the ASCIIcast JSON
# header. We first save a length as an int, then the JSON.

proc createASciicastHeader*(title = "Terminal Capture", idle_time_limit = 1.5,
  command = "", fg_theme = "", bg_theme = "", palette_theme = ""):
    string {.cdecl.} =
  var
    shell  = getenv("SHELL")
    term   = getenv("TERM")
    (w, h) = terminalSize()
    start  = int(int(unixTimeInMs()) / 1000)

  if shell == "":
    shell = getLoginShell()
  if term == "":
    term = "xterm"


  var jobj = %* {"version": 2, "width" : w, "height" : h,
                  "timestamp" : start, "title" : title}

  jobj["env"] = %* { "TERM" : term, "SHELL" : shell }

  if command != "":
    jobj["command"] = %* command

  if fg_theme != "" or bg_theme != "" or palette_theme != "":
    jobj["theme"] = %* { "fg" : fg_theme, "bg" : bg_theme,
                         "palette" : palette_theme }
  return $(jobj)

proc handleCapture*(state:   var CaptureState,
                    unused:  pointer,
                    capture: cstring,
                    caplen:  int) {.cdecl.} =
  var hdr: WriteHeader
  hdr.timeStamp   = unixTimeInMs()

  if gotResize:
    hdr.contentLen = -1
    var (w, h)     = terminalSize()

    rawFdWrite(state.fd, addr hdr, csize_t(sizeof(hdr)))
    rawFdWrite(state.fd, addr w, csize_t(sizeof(w)))
    rawFdWrite(state.fd, addr h, csize_t(sizeof(h)))

  hdr.contentLen  = caplen

  rawFdWrite(state.fd, addr hdr, csize_t(sizeof(hdr)))
  rawFdWrite(state.fd, capture, csize_t(caplen))

proc handleInput*(state:   var CaptureState,
                  unused:  pointer,
                  capture: cstring,
                  caplen:  int) {.cdecl.} =

  if state.includeInput:
    state.handleCapture(unused, capture, caplen)

  if state.inputLog != nil:
    state.inputLog.write(`$`(capture).replace("\r", "\n"))

proc captureSetup*(state: var CaptureState, fd: cint,
                   exe = "", args: seq[string] = @[]) {.cdecl.} =
  var
    cmd    = exe & args.join(" ")
    header = createAsciiCastHeader(command = cmd)
    l      = header.len()

  state.fd = fd

  fd.rawFdWrite(addr l, csize_t(sizeof(int)))
  fd.rawFdWrite(addr header[0], csize_t(l))

proc captureProcess*(exe: string, args: seq[string], fd: cint,
                     inputlog = "", includeInput = false): int
    {.cdecl, discardable.} =
  ## includeInput should be true when echo is off remotely.
  var
    subproc: SubProcess
    state:   CaptureState

  state.captureSetup(fd, exe, args)
  state.includeInput = includeInput

  if inputLog != "":
    state.inputLog = open(resolvePath(inputLog), fmWrite)

  subproc.initSubprocess(exe, @[exe] & args)
  subproc.setStartupCallback(SpStartupCallback(registerPtyFd))
  subproc.usePty()
  subproc.setExtra(addr state)
  subproc.setPassthrough(SpIoAll, false)
  subproc.setIoCallback(SpIoStdin,  cast[SubProcCallback](handleInput))
  subproc.setIoCallback(SpIoStdout, cast[SubprocCallback](handleCapture))
  subproc.run()

  result = subproc.getExitCode()

  if inputLog != "":
    state.inputLog.close()

proc openWithoutClobber*(filename: string): (File, string) {.cdecl.} =
  var
    path = filename.resolvePath()
    f    = open(path, fmAppend)

  if f.getFilePos() != 0:
    f.close()
    let (dir, name, ext) = path.splitFile()
    return createTempFile(name & "-", ext, dir)
  else:
    return (f, path)

proc captureProcess*(exe: string, args: seq[string], inputLogExt = "",
                     includeInput = false): string {.cdecl.} =
  # Throws exception if the open fails.
  var
    f:           File
    desiredPath: string = resolvePath("output.cap10")
    path:        string

  (f, path) = openWithoutClobber(desiredPath)

  captureProcess(exe, args, f.getFileHandle(),
                 path & inputLogExt, includeInput)
  f.close()

  return path

const logext = ".log"

proc cmdCaptureProcess*(exe: string, args: seq[string]) =
      print("<atomiclime>Recording.</atomiclime>")
      let name = captureProcess(exe, args, logExt)
      restoreTermState()
      print("<atomiclime>Output saved to: '" & name & "'</atomiclime><br>" &
        "<atomiclime>Input log in: " & name & logExt & "'</atomiclime><br>")
