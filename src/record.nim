## :Author: John Viega (john@crashoverride.com)
## :Copyright: 2023, Crash Override, Inc.

import nimutils, terminal, common, std/tempfiles, os

{.emit: """
extern ssize_t read_one(int, char *, size_t);
extern bool write_data(int, char *, size_t);
""".}


proc handleCapture*(state:   var CaptureState,
                    unused:  pointer,
                    capture: cstring,
                    caplen:  int) {.cdecl.} =

  var hdr: WriteHeader
  hdr.timeStamp   = unixTimeInMs()
  hdr.contentLen  = caplen

  rawFdWrite(state.fd, addr hdr, csize_t(sizeof(hdr)))
  rawFdWrite(state.fd, capture, csize_t(caplen))

proc handleInput*(state:   var CaptureState,
                  unused:  pointer,
                  capture: cstring,
                  caplen:  int) {.cdecl.} =

  if state.includeInput:
    state.handleCapture(unused, capture, caplen)

proc captureSetup*(state: var CaptureState, fd: cint) {.cdecl.} =
  var
    (w, h)     = terminalSize()
    #startTime = unixTimeInMs()

  state.fd = fd

  fd.rawFdWrite(addr w, csize_t(sizeof(int)))
  fd.rawFdWrite(addr h, csize_t(sizeof(int)))
  #fd.rawFdWrite(addr startTime, csize_t(sizeof(uint64)))

proc captureProcess*(exe: string, args: seq[string], fd: cint,
                     includeInput = false): int
    {.cdecl, discardable.} =
  ## includeInput should be true when echo is off remotely.
  var
    subproc: SubProcess
    state:   CaptureState

  state.captureSetup(fd)
  state.includeInput = includeInput
  subproc.initSubprocess(exe, @[exe] & args)
  subproc.usePty()
  subproc.setExtra(addr state)
  subproc.setPassthrough(SpIoAll, false)
  subproc.setIoCallback(SpIoStdin,  cast[SubProcCallback](handleInput))
  subproc.setIoCallback(SpIoStdout, cast[SubprocCallback](handleCapture))
  subproc.run()

  result = subproc.getExitCode()

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

proc captureProcess*(exe: string, args: seq[string]): string {.cdecl.} =
  # Throws exception if the open fails.
  var
    f:           File
    desiredPath: string = resolvePath("output.cap10")
    path:        string


  (f, path) = openWithoutClobber(desiredPath)

  captureProcess(exe, args, f.getFileHandle())
  f.close()

  return path
