import cap10


when isMainModule:
   var s: ExpectObject

   s.spawnSession(captureFile = "expect.cap10", passthrough = true)
   s.send("# Let's play a small cast of us running chalk.")
   s.expect(".*\\$ ")
   s.send("./cap10 play basic.cap10")
   s.expect("Playback complete")
   s.expect(".*\\$ ")
   s.send("ls")
   s.expect(".*\\$ ")
   s.send("# let's convert that to asciicast")
   s.expect(".*\\$ ")
   s.send("./cap10 convert basic.cap10")
   s.expect(".*\\$ ")
   s.send("# Let's play it in asciinema now")
   s.expect(".*\\$ ")
   s.send("asciinema play basic.cast && echo Done")
   s.expect("Done")
   s.expect(".*\\$ ")
   s.send("# Let's look at this demo script.")
   s.expect(".*\\$ ")
   s.send("cat demo.nim")
   s.expect(".*\\$ ")
   s.send("# Okay, that's enough for now.")
   s.expect(".*\\$ ")
   s.send("exit")
   s.expect("eof")
