# Package

version       = "0.2.2"
author        = "Guilherme Leoi"
description   = "Discord Bot that randomly fetches messages from a channel and re-sends them in different ways"
license       = "GPL-3.0-only"
srcDir        = "src"
binDir        = "bin"
bin           = @["carlito"]


# Dependencies

requires "nim >= 1.6.0"
requires "dimscord >= 1.4.0"
requires "dotenv >= 2.0.0"
requires "puppy >= 2.0.0"
