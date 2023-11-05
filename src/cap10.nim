## :Author: John Viega (john@crashoverride.com)
## :Copyright: 2023, Crash Override, Inc.
##
## I'm going to hook up con4m for command line arguments
## after my next batch of con4m work. Until then, a lot
## of the options are going to stay hardcoded.

import record, play, nimutils, os, expect, convert, common, std/terminal
export record, play, expect, common

proc usage() {.noreturn .} =
   print("""<h1>Usage: cap10 (record | play | convert) [arguments]</h1>
<table>
 <tr><colgroup><col width=30><col width=70></colgroup><th>record [command]</th><td>Record terminal output, running the named command if provided; spawning a shell if not. Saves to output.cap10 in the current working directory.</td></tr>
 <tr><th>play [-i] [capfile]*</th><td>Plays named capture files, in order. If no file names are provided, assumes 'output.cap10'. If the <em>-i</em> flag is passed, then you can use space to pause/play and q to quit. This is off by default at the moment.</td></tr>
 <tr><th>convert [capfile]</th><td>Conver a cap10 file to an asciicast file.</td></tr></table>
""")
   quit(1)

when isMainModule:
  useNativeLocale()
  useCurrentTermStateOnSignal()

  setStyle("h1", newStyle(fgColor = "yellow", bgColor = "blue",
                          underline = UnderlineSingle))
  setStyle("th", newStyle(overflow = OWrap,
                 tmargin = 0, fgColor = "lime", align = AlignC))
  var params = commandLineParams()
  if len(params) >= 1:
    if params[0] in ["record", "rec"]:
      if len(params) == 1:
        params.add(getLoginShell())
        params.add("-i")
      cmdCaptureProcess(params[1], params[2 .. ^1])

    elif params[0] == "play":
      if len(params) == 1 or (len(params) == 2 and params[1] == "-n"):
        params.add("output.cap10")

      var allowInput = if "-i" in params: true else: false

      cmdPlaybackProcess(params[1 .. 1], allowInput)

    elif params[0] == "convert":
      if len(params) == 1:
        params.add("output.cap10")

      toAsciiCast2(params[1])
    else:
      usage()
  else:
    usage()

restoreTermState()
showCursor()
quit()
