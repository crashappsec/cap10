import strutils

switch("debugger", "native")
switch("d", "nimPreviewHashRef")
switch("d", "ssl")
switch("d", "useOpenSSL3")
switch("gc", "refc")

when not defined(debug):
    switch("d", "release")
    switch("opt", "speed")

var targetArch = hostCPU

when defined(macosx):
  # -d:arch=amd64 will allow you to specifically cross-compile to intel.
  # The .strdefine. pragma sets the variable from the -d: flag w/ the same
  # name, overriding the value of the const.
  const arch          {.strdefine.} = "detect"

  var
    targetStr  = ""

  if arch == "detect":
    # On an x86 mac, the proc_translated OID doesn't exist. So if this
    # returns either 0 or 1, we know we're running on an arm. Right now,
    # nim will always use rosetta, so should always give us a '1', but
    # that might change in the future.
    let sysctlOut = staticExec("sysctl -n sysctl.proc_translated")

    if sysctlOut in ["0", "1"]:
      targetArch = "arm64"
    else:
      targetArch = "amd64"
  else:
    echo "Override: arch = " & arch

  if targetArch == "arm64":
    echo "Building for arm64"
    targetStr = "arm64-apple-macos13"
  elif targetArch == "amd64":
    targetStr = "x86_64-apple-macos13"
    echo "Building for amd64"
  else:
    echo "Invalid target architecture for MacOs: " & arch
    quit(1)

  switch("cpu", targetArch)
  switch("passc", "-flto -target " & targetStr)
  switch("passl", "-flto -w -target " & targetStr &
        "-Wl,-object_path_lto,lto.o")

elif defined(linux):
  switch("passc", "-static")
  switch("passl", "-static")
else:
  echo "Platform not supported."
  quit(1)

var
  subdir = ""

for item in listDirs(thisDir()):
  if item.endswith("/files"):
    subdir = "/files"
    break

proc getEnvDir(s: string, default = ""): string =
  result = getEnv(s, default)
  if not result.endsWith("/"):
    result &= "/"

exec thisDir() & subdir & "/bin/buildlibs.sh " & thisDir() & "/files/deps"

var
  default  = getEnvDir("HOME") & ".local/c0"
  localDir = getEnvDir("LOCAL_INSTALL_DIR", default)
  libDir   = localdir & "libs"
  libs     = ["ssl", "crypto", "gumbo"]

when defined(linux):
  var
    muslPath = localdir & "musl/bin/musl-gcc"
  switch("gcc.exe", muslPath)
  switch("gcc.linkerexe", muslPath)

for item in libs:
  let libFile = "lib" & item & ".a"

  switch("passL", libDir & "/" & libFile)
  switch("dynlibOverride", item)
