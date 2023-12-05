version     = "0.3.0"
author      = "John Viega"
description = "A tool to capture and replay command line terminal sessions"
license     = "Apache-2.0"
bin         = @["cap10", "demo", "apidemo"]
srcDir      = "src"

requires "nim >= 2.0.0"
requires "https://github.com/crashappsec/nimutils#de08f11339ccd5d06079747271329b29ca9e27a9"
