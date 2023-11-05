## :Author: John Viega (john@crashoverride.com)
## :Copyright: 2023, Crash Override, Inc.
##
## I'm going to hook up con4m for command line arguments
## after my next batch of con4m work. Until then, a lot
## of the options are going to stay hardcoded.

import record, play, nimutils, os, expect, convert, common, std/terminal
export record, play, expect, common

const logext = ".log"

when isMainModule:
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
      print("<atomiclime>Recording.</atomiclime><br>", ensureNl = false)
      let name = captureProcess(params[1], params[2 .. ^1], logExt)
      restoreTermState()
      print("<atomiclime>Output saved to: '" & name & "'</atomiclime><br>" &
        "<atomiclime>Input log in: " & name & logExt & "'</atomiclime><br>")

    elif params[0] == "play":
      if len(params) == 1 or (len(params) == 2 and params[1] == "-n"):
        params.add("output.cap10")
      var allowInput = false
      if "-i" in params:
        allowInput = true
      for item in params[1 .. ^1]:
        if item == "-i":
          continue
        replayProcess(item, allowInput)
      restoreTermState()
      print("<atomiclime>Playback complete.</atomiclime><br>", ensureNl = false)
    elif params[0] == "convert":
      if len(params) == 1:
        params.add("output.cap10")
      toAsciiCast2(params[1])
      restoreTermState()
      print("<atomiclime>Conversion complete.</atomiclime><br>",
            ensureNl = false)
    else:
      print("""<h1>Usage: cap10 (record | play) [arguments]</h1>
<table>
 <tr><colgroup><col width=30><col width=70></colgroup><th>record [command]</th><td>Record terminal output, running the named command if provided; spawning a shell if not. Saves to output.cap10 in the current working directory.</td></tr>
 <tr><th>play [-i] [capfile]*</th><td>Plays named capture files, in order. If no file names are provided, assumes 'output.cap10'. If the <em>-i</em> flag is passed, then you can use space to pause/play and q to quit. This is off by default at the moment.</td></tr>
 <tr><th>convert [capfile]</th><td>Conver a cap10 file to an asciicast file.</td></tr></table>
""", ensureNl = false)
      quit(1)

restoreTermState()
showCursor()
quit()
