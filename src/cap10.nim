## :Author: John Viega (john@crashoverride.com)
## :Copyright: 2023, Crash Override, Inc.

import record, play, nimutils, os, expect
export record, play, expect


when isMainModule:
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
      let name = captureProcess(params[1], params[2 .. ^1])
      print("<atomiclime>Output saved to '" & name & "'</atomiclime><br>",
            ensureNl = false)
      quit(0)
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
      print("<atomiclime>Playback complete.</atomiclime><br>", ensureNl = false)
      quit(0)

  print("""<h1>Usage: cap10 (record | play) [arguments]</h1>
<table>
 <tr><colgroup><col width=30><col width=70></colgroup><th>record [command]</th><td>Record terminal output, running the named command if provided; spawning a shell if not. Saves to output.cap10 in the current working directory.</td></tr>
 <tr><th>play [-i] [capfile]*</th><td>Plays named capture files, in order. If no file names are provided, assumes 'output.cap10'. If the <em>-i</em> flag is passed, then you can use space to pause/play and q to quit. This is off by default at the moment.</td>
</tr></table>
""", ensureNl = false)
  quit(1)
