version     = "0.3.0"
author      = "John Viega"
description = "A tool to capture and replay command line terminal sessions"
license     = "Apache-2.0"
bin         = @["cap10", "demo"]
srcDir      = "src"

requires "nim >= 2.0.0"
requires "https://github.com/crashappsec/nimutils#95c0657dd9d150f25ed2b8ef991cb9b9e5b05846"
