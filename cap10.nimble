version = "0.3.0"
author  = "John Viega"
description = "A tool to capture and replay command line terminal sessions"
license = "Apache-2.0"
bin     = @["cap10", "demo"]
srcDir  = "src"

requires "nim >= 2.0.0"
requires "https://github.com/crashappsec/nimutils#77b16328d02ce01ce6c4eceab26e20c2b1be32d4"
