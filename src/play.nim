## :Author: John Viega (john@crashoverride.com)
## :Copyright: 2023, Crash Override, Inc.

import os, nimutils, posix, terminal, common

var
  paused = false
  exit   = false
  termSave: Termcap

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


proc ensureTerminalDimensions(f: File) {.cdecl.} =
  var
    x: tuple[w, h: int]
    tupPtr = addr x

  discard f.readBuffer(tupPtr, sizeof(x))

  while true:
    let (curw, curh) = terminalSize()

    if curw >= x.w and curh >= x.h:
      break

    stdout.write("\e[2J\e[H")
    echo "Replay requires: width of ", x.w, " columns; height of ", x.h,
       " rows."
    echo "Current size is: width of ", curw, " columns; height of ", curh,
       " rows."
    sleep(10)

proc replayProcess*(fname:   string,
                    allowInput           = true,
                    maxTimeBetweenEvents = 1500) {.cdecl.} =
  var
    sleepTime: int
    buf:       array[1024, uint8]
    hdr:       WriteHeader
    spacings:  seq[uint64] = @[0]
    lastStamp: uint64      = 0
    hdrptr                 = addr hdr
    bufPtr64               = cast[ptr uint64](addr buf[0])
    f                      = open(fname, fmRead)
    startTime: uint64
    epochIx                = 0
    lastEpoch              = -1
    maxLen                 = f.getFileSize()
    switchboard: Switchboard
    stdinFd:     Party
    cb:          Party
    tv:          Timeval

  termcapGet(termSave)
  termcapSetTypicalParent()

  f.setFilePos(0)
  ensureTerminalDimensions(f)



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
        termcapSet(termSave)
        print("<br><atomiclime>Quitting early.</atomiclime><br>",
              ensureNl = false)
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
  termcapSet(termSave)
