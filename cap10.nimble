version     = "0.3.0"
author      = "John Viega"
description = "A tool to capture and replay command line terminal sessions"
license     = "Apache-2.0"
bin         = @["cap10", "demo"]
srcDir      = "src"

requires "nim >= 2.0.0"
requires "https://github.com/crashappsec/nimutils#03e5a78cbf24bfd4331ce002bb6b132d275c70f7"
