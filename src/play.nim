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

proc applyHeader(hdr: string): int {.cdecl.} =
  try:
    var
      jObj = parseJson(hdr)
      w    = jObj["width"].getInt()
      h    = jObj["height"].getInt()
      t    = int(jObj["idle_time_limit"].getFloat() * 1000)

    if w <= 0 or h <= 0:
      return

    stdout.write("\e[8;" & $(h) & ";" & $(w) & "t")
    return t
  except:
    discard

proc replayProcess*(fname:   string,
                    allowInput           = true,
                    maxTimeBetweenEvents = 1500) {.cdecl.} =
  var
    buf:         array[1024, uint8]
    hdr:         WriteHeader
    lastStamp:   uint64      = 0
    hdrptr                   = addr hdr
    f                        = open(fname, fmRead)
    maxLen                   = f.getFileSize()
    tty                      = open("/dev/tty", fmWrite)
    sepTime:     int
    sleepTime:   int
    hdrLen:      int
    b:           ptr char
    hdrStr:      string
    termSave:    Termcap
    newTerm:     Termcap
    switchboard: Switchboard
    stdinFd:     Party
    cb:          Party
    tv:          Timeval

  discard dup2(tty.getFileHandle(), 1)
  # tcGetAttr(cint(1), newterm)
  # newTerm.rawMode()

  f.setFilePos(0)

  try:
    discard f.readBuffer(addr hdrLen, sizeof(int))
    b = cast[ptr char](alloc(hdrLen + 1))
    discard f.readBuffer(b, hdrLen)

    hdrStr = binaryCstringToString(cast[cstring](b), hdrLen)
    dealloc(b)
    sepTime = applyHeader(hdrStr)
    if sepTime > maxTimeBetweenEvents or sepTime == 0:
      sepTime = maxTimeBetweenEvents

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
        print("<br><atomiclime>Quitting early.</atomiclime><br>",
              ensureNl = false)
        quit(0)
      if paused:
        sleep(100)
        continue

    discard f.readBuffer(hdrptr, sizeof(WriteHeader))

    if hdr.contentLen == -1:
      var w, h: int
      discard f.readBuffer(addr w, sizeof(w))
      discard f.readBuffer(addr h, sizeof(h))
      # Not sure we need to process the resize at all, but if we do,
      # all the sudden we will need to keep track of UTF-8 code point
      # state *and* ansi term state, so let's avoid this for now.
      #
      # Really, probably what we'd do to be safe is look for a newline or
      # \e and inject before those.
      #
      # But really, we're only capturing resize info rn because
      # asciicast wants the info.
      continue

    discard f.readBytes(buf, 0, hdr.contentLen)

    sleepTime = int(hdr.timeStamp - lastStamp)
    lastStamp = hdr.timeStamp

    if sleepTime > sepTime:
      sleepTime = sepTime

    if sleepTime > 0:
      sleep(sleepTime)

    rawFdWrite(cint(1), addr buf, csize_t(hdr.contentLen))
  sleep(400)
  tty.close()
