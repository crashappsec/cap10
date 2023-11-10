import expect, common, nimutils, strutils

proc showTitle(ctx: var ExpectObject, x: string, before = 1000, after = 2000) =
  once:
    cap10ThemeSetup()
  if before > 0:
    ctx.pollFor(before)
  echo("")
  print("""
<center><table>
<colgroup><col width=80%></colgroup>
<tbody>
<tr><td><p><center>
""" & x & """</center></p><br><br></td></tr>
</tbody></table></center><br>
""")
  ctx.send("")
  if after > 0:
    ctx.pollFor(after)

var s: ExpectObject

var keptStuff: string

proc customMatch(s: string): (int, string) =
  if "exit" in s:
    return (-1, "abort")
  let
    match1 = "Conversion complete"
    n      = s.find(match1)
    match2 = "$ "

  if n == -1:
    return (-1, "")

  let
    pos = n + len(match1)
    m   = s[n + len(match1) .. ^1].find(match2)

  if m == -1:
    return (-1, "")

  keptStuff = s
  return (m + pos, "match")

proc basicDemo() =
  s.showTitle("Let's start by playing a small cap10 recording of me manually running our command 'chalk'.")
  s.send("./cap10 play basic.cap10")
  s.expect("Playback complete")
  s.expect(".*\\$ ")
  s.showTitle("Great. Now, let's go ahead and convert that to asciicast format, so we can see how well it works there.")
  s.send("./cap10 convert basic.cap10")
  if s.expect(customMatch) == "abort":
    s.showTitle("Ending early.\n")
    return
  s.showTitle("Now, let's go ahead and play it in asciinema.")
  s.send("asciinema play basic.cast && echo Done")
  s.expect("Done")
  s.expect(".*\\$ ")
  s.showTitle("We can convert the asciicast to a gif for our web site, using the asciicast gif generator (https://github.com/asciinema/agg)")
  s.send("agg basic.cast basic.gif")
  s.expect(".*\\$ ")
  s.showTitle("""Now, you can load 'basic.gif' in your browser!<p>

Note that, when recording a session, by running 'cap10 cap' instead
of 'cap10 record' you can automatically generate cap10, asciicast and
gif output in one command.
</p>""")
  s.send("exit")
  s.expect("eof")

when isMainModule:
  # While the SpawnSession call can do capture of the sub-process, if
  # you want to capture the banners too, you don't need to capture here;
  # wrap it by running this demo in cap10

  useNativeLocale()
  useCurrentTermStateOnSignal()
  s.spawnSession(passthrough = true)
  basicDemo()


#proc chalkDemo() =
#  showTitle("""<p>In this demo, we're going to use Chalk to automatically
#build and sign a container, and then look at the signature.</p><p> We'll
# start by """)

#s.send("alias docker=chalk")
#docker login
#git clone https://github.com/dockersamples/wordsmith
#docker build -t ghcr.io/viega/wordsmith:latest . --push
#chalk extract ghcr.io/viega/wordsmith:latest
