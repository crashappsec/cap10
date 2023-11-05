import os, nimutils, common, json, strutils, unicode

proc escapeAllJson*(s: string, result: var string) =
  # If we use the built-in Nim version of this, we end up generating
  # output that Asciinema can't handle, because it goes one byte at
  # a time, when it really needs to go one CODEPOINT at a time.
  # Silly Nim.
  result.add("\"")

  for c in s.toRunes():
    case c
    of Rune('\n'):
      result.add("\\n")
    of Rune('\b'):
      result.add("\\b")
    of Rune('\f'):
      result.add("\\f")
    of Rune('\t'):
      result.add("\\t")
    of Rune('\v'):
      result.add("\\u000b")
    of Rune('\r'):
      result.add("\\r")
    of Rune('"'):
      result.add("\\\"")
    of Rune('\\'):
      result.add("\\\\")
    of Rune(0x00) .. Rune(0x07),
       Rune(0x0e) .. Rune(0x1f),
       Rune(0x7f):
      result.add("\\u" & toHex(ord(c), 4))
    else:
      result.add($(c))

  result.add("\"")

proc escapeAllJson*(s: string): string =
  result = newStringOfCap(s.len + s.len shr 3)
  s.escapeAllJson(result)

template makeUtf8CutoffAdjustments() =
  var
    s:           string
    i:           int
    expectedNum: int
  ## For our binary file format, we capture and replay 512-byte chunks
  ## directly from the file descriptor. There, if UTF-8 characters get
  ## split between chunks, it's no big deal, because they will be
  ## played back in a consecutive stream.
  ##
  ## However, when converting to JSON, we need to make sure NOT to
  ## split bits up. So when we're about to chop off a character, we'll
  ## save it in buffer, and append it to the next packet, which we
  ## can be sure is coming.

  if waiting != 0:
    for n in 0 ..< waiting:
      s.add(utf8Buffer[n])
    payload = s & payload
    waiting = 0


  i = payload.validateUtf8()
  while true:
    if i != -1:
      waiting = payload.len() - i
      if waiting >= 4:
        let n = payload[i + 1 .. ^1].validateUtf8()
        if n == -1:
          waiting = 0
          break
        else:
          i += n
          continue
      for n in 0 ..< waiting:
        utf8Buffer[n] = payload[i + n]
      payload = payload[0 ..< i]
    break

proc toAsciiCast2*(fname: string, outfname = "") {.cdecl.} =
  var
    buf:         array[1024, uint8]
    hdr:         WriteHeader
    hdrptr                   = addr hdr
    inf                      = open(fname, fmRead)
    maxLen                   = inf.getFileSize()
    parts                    = fname.splitFile()
    startTime:   uint64      = 0
    outf:        File
    utf8Buffer:  array[4, char]
    waiting:     int
    hdrLen:      int
    payload:     string
    b:           ptr char
    hdrStr:      string
    progress:    ProgressBar
    processed:   int

  if outfname != "":
    outf = open(outfname, fmWrite)
  else:
    outf = open(joinPath(parts.dir, parts.name & ".cast"), fmWrite)

  inf.setFilePos(0)
  try:
    discard inf.readBuffer(addr hdrLen, sizeof(int))
    b = cast[ptr char](alloc(hdrLen + 1))
    discard inf.readBuffer(b, hdrLen)

    hdrStr = binaryCstringToString(cast[cstring](b), hdrLen)
    dealloc(b)
    discard parseJson(hdrStr)
  except:
        print("<br><atomiclime>Invalid cap10 file.</atomiclime><br>",
              ensureNl = false)
        quit(1)

  print("<br><atomiclime>Converting...</atomiclime><br>")
  outf.write(hdrStr)
  outf.write("\n")


  progress.initProgress(maxLen - inf.getFilePos())

  while inf.getFilePos() < maxLen:
    discard inf.readBuffer(hdrptr, sizeof(WriteHeader))

    if hdr.contentLen == -1:
      var w, h: int
      discard inf.readBuffer(addr w, sizeof(w))
      discard inf.readBuffer(addr h, sizeof(h))
      var t = int(hdr.timeStamp - startTime) / 1000
      outf.write("[" & $(t) & ",\"r\", \"" & $(w) & "x" & $(h) & "\"]")
      continue

    discard inf.readBytes(buf, 0, hdr.contentLen)

    if startTime == 0:
      startTime = hdr.timeStamp

    payload = binaryCStringToString(cast[cstring](addr buf), hdr.contentLen)
    makeUtf8CutoffAdjustments()

    var t = int(hdr.timeStamp - startTime) / 1000

    outf.write("[" & $(t) & ",\"o\", " & payLoad.escapeAllJson() & "]\n")
    processed += hdr.contentLen + sizeof(WriteHeader)

    progress.update(processed)

  inf.close()
  outf.close()
  restoreTermState()
  print("<atomiclime>Conversion complete.</atomiclime><br>")
