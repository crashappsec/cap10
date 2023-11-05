## :Author: John Viega (john@crashoverride.com)
## :Copyright: 2023, Crash Override, Inc.

import nimutils, posix, tables, std/terminal, std/termios

var
  TIOCSWINSZ*{.importc, header: "<sys/ioctl.h>".}: culong
  SIGWINCH*  {.importc, header: "<signal.h>".}: cint
  LC_ALL*    {.importc, header: "<locale.h>".}: cint

proc setlocale*(category: cint, locale: cstring): cstring {. importc, cdecl,
                                nodecl, header: "<locale.h>", discardable .}

proc useNativeLocale*() =
  setlocale(LC_ALL, cstring(""))

type
  CaptureContentType = enum CctInput, CctOutput
  CaptureState* = object
    includeInput*:    bool
    fd*:              cint
    inputLog*:        File

  WriteHeader* = object
    timeStamp*:      uint64
    contentLen*:     int

var
  gotResize*              = false
  winchProxy              = true
  winchProxyFd:   cint    = -1
  savedTermState: Termcap

proc setWinchProxy*(proxy: bool) =
  winchProxy = proxy

proc registerPtyFd*(ctx: var SubProcess) {.cdecl, gcsafe.} =
  ## Called once the forkpty() call succeeds to stash the FD
  ## for the sigwinch signal handler.
  winchProxyFd = ctx.getPtyFd()

template restoreTermState*(how = TcsaConst.TCSAFLUSH) =
  tcSetAttr(cint(1), how, savedTermState)

proc restoreOnQuit() {.noconv.} =
  restoreTermState()
  showCursor()
  stdout.close()

let sigNameMap = { 1: "SIGHUP", 2: "SIGINT", 3: "SIGQUIT", 4: "SIGILL",
                   6: "SIGABRT",7: "SIGBUS", 9: "SIGKILL", 11: "SIGSEGV",
                   15: "SIGTERM", 28: "SIGWINCH" }.toTable()

proc onParentResize(signal: cint) {.noconv.} =
  gotResize = true

  var
    newWinsz:   IoCtlWinSize
    childWinSz: IoCtlWinSize

  if winchProxyFd == -1:
    return

  discard ioctl(1,  TIOCGWINSZ, addr newWinsz)
  discard ioctl(winchProxyFd, TIOCSWINSZ, addr newWinsz)

  # If we don't do a little bit of busy-waiting, it's definitely
  # possible that the signal will not get delivered.  Specifically, on
  # my mac, I've got a little program that does nothing but spin until
  # it gets SIGWINCH, at which point it prints out its new dimensions.
  #
  # Without this loop, or something else that takes up time, (like an
  # IO call), the parent process never sees the parent fd as ready fro
  # read, which means the signal did not get delivered.
  #
  # I've seen reports of this on Linux too; this seems to be a
  # somewhat unavoidable race condition in the OS, and waiting like
  # this before returning seems to be the only fix?
  #
  # If we just wait until the ioctl condition is true, we can also get hit
  # by the race condition and hang the parent.
  #
  # Should probably use a call to check the clock and limit this to a
  # wall-clock time, otherwise this # might eventually end up too low
  # on some machines (and might be too high on some machines now).

  for i in 0 ..< 1000000:
    discard ioctl(winchProxyFd, TIOCGWINSZ, addr childWinsz)
    if childWinSz != newWinSz:
      break

proc regularTerminationSignal(signal: cint) {.noconv.} =
  showCursor()
  stdout.close()

  echo "Aborting due to signal: " & sigNameMap[signal]  & "(" & $(signal) & ")"

  var sigset:  SigSet

  discard sigemptyset(sigset)

  for signal in [SIGHUP, SIGINT, SIGQUIT, SIGILL, SIGABRT, SIGBUS, SIGKILL,
                 SIGSEGV, SIGTERM]:
    discard sigaddset(sigset, signal)
  discard sigprocmask(SIG_SETMASK, sigset, sigset)

  exitnow(signal + 128)

proc setupParentSignalHandlers*() =
  var handler: SigAction

  handler.sa_handler = regularTerminationSignal
  handler.sa_flags   = 0

  for signal in [SIGHUP, SIGINT, SIGQUIT, SIGILL, SIGABRT, SIGBUS, SIGKILL,
                 SIGSEGV, SIGTERM]:
    discard sigaction(signal, handler, nil)

  if winchProxy:
    signal(SIGWINCH, onParentResize)

proc useCurrentTermStateOnSignal*(installHandlers = true) =
  tcGetAttr(cint(1), savedTermState)
  if installHandlers:
    setupParentSignalHandlers()
