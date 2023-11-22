## :Author: John Viega (john@crashoverride.com)
## :Copyright: 2023, Crash Override, Inc.
##
## I'm going to hook up con4m for command line arguments
## after my next batch of con4m work. Until then, a lot
## of the options are going to stay hardcoded.

import record, play, nimutils, os, expect, convert, common, std/terminal
export record, play, expect, common

proc usage() {. noreturn .} =
  var 
    rec  = text("Record terminal output, running the named command if provided; spawning a shell if not. Saves to output.cap10 in the current working directory.")
    play = text("Plays named capture files, in order. If no file names are provided, assumes 'output.cap10'. If the ") + em("-i") + text(" flag is passed, then you can use space to pause/play and q to quit. This is off by default at the moment.")
    convert = text("Convert a cap10 file to an asciicast v2 file.")
    cap = text("Record, producing full capture (cap10, input log, asciicast and gif, if agg is installed).")
    cmds = @[@[em("record [command]"), rec],
             @[em("play [-i] [capfile]*"), play],
             @[em("convert [capfile]"), convert],
             @[em("cap [command]"), cap]]

  print(quickTable(cmds, noheaders = true, title = "cap10: Capture, replay, and convert terminal recordings"))
  quit(1)

when isMainModule:
  cap10ThemeSetup()
  useNativeLocale()
  useCurrentTermStateOnSignal()

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
        print(h2("Skipping gif conversion; agg not found. Install " &
          "https://github.com/asciinema/agg for next time."))

      else:
        print(h2("Creating gif by calling agg:"))
        let
          res         = runCommand(aggOpts[0], @[acFile, gifFile],
                                   passthrough = SpIoStdout, capture = SpIoNone)
        removeFile(c10File)
        removeFile(c10File & ".log")
        echo("")
        if res.getExit() == 0:
          removeFile(acFile)
          print(h2(text("Output gif to:  ") + em(gifFile)))
        else:
          print(h2(text("Asciicast file: ") + em(acFile)))

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
