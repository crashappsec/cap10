## :Author: John Viega (john@crashoverride.com)
## :Copyright: 2023, Crash Override, Inc.


import os, nimutils, posix, common, json

var
  paused = false
  exit   = false

proc handlePlayerInput(ignore0: pointer,
                       ignore1: pointer,
                       capture: cstring,
                       caplen:  int) {.cdecl.} =
  var incap = bytesToString(cast[ptr UncheckedArray[char]](capture), caplen)

  for ch in incap:
    if ch == ' ':
      paused = not paused
    elif ch == 'q':
      exit = true

proc applyHeader(hdr: string) {.cdecl.} =
  try:
    var
      jObj = parseJson(hdr)
      w    = jObj["width"].getInt()
      h    = jObj["height"].getInt()

    if w <= 0 or h <= 0:
      return

    stdout.write("\e[8;" & $(h) & ";" & $(w) & "t")
  except:
    discard


proc replayProcess*(fname:   string,
                    allowInput           = true,
                    maxTimeBetweenEvents = 1500) {.cdecl.} =
  var
    buf:         array[1024, uint8]
    hdr:         WriteHeader
    spacings:    seq[uint64] = @[0]
    lastStamp:   uint64      = 0
    hdrptr                   = addr hdr
    bufPtr64                 = cast[ptr uint64](addr buf[0])
    f                        = open(fname, fmRead)
    epochIx                  = 0
    lastEpoch                = -1
    maxLen                   = f.getFileSize()
    tty                      = open("/dev/tty", fmWrite)
    sleepTime:   int
    hdrLen:      int
    b:           ptr char
    hdrStr:      string
    termSave:    Termcap
    newTerm:     Termcap
    startTime:   uint64
    switchboard: Switchboard
    stdinFd:     Party
    cb:          Party
    tv:          Timeval

  discard dup2(tty.getFileHandle(), 1)
  tcGetAttr(cint(1), termSave)
  newTerm = termSave
  newTerm.c_iflag = newTerm.c_iflag and not uint32(IXON)
  newTerm.c_lflag = newTerm.c_lflag and (not uint32(ECHO) or uint32(ICANON))
  newTerm.c_cc[int(VMIN)]  = 0
  newTerm.c_cc[int(VTIME)] = 1

  tcSetAttr(0, TCSAFLUSH, newTerm)

  f.setFilePos(0)

  try:
    discard f.readBuffer(addr hdrLen, sizeof(int))
    b = cast[ptr char](alloc(hdrLen + 1))
    discard f.readBuffer(b, hdrLen)

    hdrStr = binaryCstringToString(cstring(b), hdrLen)
    dealloc(b)
    applyHeader(hdrStr)
  except:
        print("<br><atomiclime>Invalid cap10 file.</atomiclime><br>",
              ensureNl = false)
        quit(1)

  if allowInput:
    tv.tv_sec  = Time(0)
    tv.tv_usec = Suseconds(0)

    switchboard.initSwitchboard()
    switchboard.initPartyFd(stdinFd, 0, sbRead)
    switchboard.initPartyCallback(cb, handlePlayerInput)
    switchboard.route(stdinFd, cb)
    switchboard.setTimeout(tv)

  while f.getFilePos() < maxLen:
    if allowInput:
      switchboard.run()

      if exit:
        tcSetAttr(cint(1), TCSAFLUSH, termSave)
        print("<br><atomiclime>Quitting early.</atomiclime><br>",
              ensureNl = false)
        sleep(200)
        quit(0)
      if paused:
        sleep(100)
        continue

    discard f.readBuffer(hdrptr, sizeof(WriteHeader))
    discard f.readBytes(buf, 0, hdr.contentLen)

    sleepTime = int(hdr.timeStamp - lastStamp)
    lastStamp = hdr.timeStamp

    if sleepTime > maxTimeBetweenEvents:
      sleepTime = maxTimeBetweenEvents

    if sleepTime > 0:
      sleep(sleepTime)

    rawFdWrite(cint(1), addr buf, csize_t(hdr.contentLen))


  tcSetAttr(cint(1), TCSAFLUSH, termSave)
  sleep(200)
  tty.close()
