## :Author: John Viega (john@crashoverride.com)
## :Copyright: 2023, Crash Override, Inc.
##
## I'm going to hook up con4m for command line arguments
## after my next batch of con4m work. Until then, a lot
## of the options are going to stay hardcoded.

import record, play, nimutils, os, expect, convert, common, std/terminal
export record, play, expect, common

proc usage() {. noreturn .} =
   print("""<atomiclime>Usage: cap10 (record | play | convert | cap) [arguments]</h1>
<table>
 <tr><colgroup><col width=30><col width=70></colgroup><th>record [command]</th><td>Record terminal output, running the named command if provided; spawning a shell if not. Saves to output.cap10 in the current working directory.</td></tr>
 <tr><th>play [-i] [capfile]*</th><td>Plays named capture files, in order. If no file names are provided, assumes 'output.cap10'. If the <em>-i</em> flag is passed, then you can use space to pause/play and q to quit. This is off by default at the moment.</td></tr>
 <tr><th>convert [capfile]</th><td>Convert a cap10 file to an asciicast v2 file.</td></tr>
 <tr><th>cap [command]</th><td>Record, producing full capture (cap10, input log, asciicast and gif, if agg is installed).</td></tr>
</table>
""")
   quit(1)

when isMainModule:
  cap10ThemeSetup()
  useNativeLocale()
  useCurrentTermStateOnSignal()

  setStyle("h1", newStyle(fgColor = "yellow", bgColor = "blue",
                          underline = UnderlineSingle))
  setStyle("th", newStyle(overflow = OWrap,
                 tmargin = 0, fgColor = "lime", align = AlignC))
  var params = commandLineParams()
  if len(params) >= 1:
    if params[0] == "cap":
      if len(params) == 1:
        params.add(getLoginShell())
        params.add("-i")
      let
        c10File = cmdCaptureProcess(params[1], params[2 .. ^1], verbose = false)
        acFile  = toAsciiCast2(c10File)
        parts   = acFile.splitFile()
        gifFile = joinPath(parts.dir, parts.name & ".gif")

      let aggOpts = findAllExePaths("agg")
      if len(aggOpts) == 0:
        print("<h2>Skipping gif conversion; agg not found. Install " &
          "https://github.com/asciinema/agg and then run 'cap10 convert'." &
          "</h2>")
      else:
        print("<h2>Creating gif by calling agg:</h2><br>")
        let
          res         = runCommand(aggOpts[0], @[acFile, gifFile],
                                   passthrough = SpIoStdout, capture = SpIoNone)
        removeFile(c10File)
        removeFile(c10File & ".log")
        if res.getExit() == 0:
          removeFile(acFile)
          print("<em>Output gif to: </em>" & gifFile)
        else:
          print("<em>Asciicast file: </em> " & acFile)

    elif params[0] in ["record", "rec"]:
      if len(params) == 1:
        params.add(getLoginShell())
        params.add("-i")
      cmdCaptureProcess(params[1], params[2 .. ^1])

    elif params[0] == "play":
      if len(params) == 1 or (len(params) == 2 and params[1] == "-n"):
        params.add("output.cap10")

      var allowInput = if "-i" in params: true else: false

      cmdPlaybackProcess(params[1 .. 1], allowInput)

    elif params[0] in ["convert", "export"]:
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
