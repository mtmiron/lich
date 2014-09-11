# Compiling it

### Ruby dependency

1) go to http://www.ruby-lang.org and download Ruby's sourcecode.
2) unpack it someplace and edit the file `./ext/Setup' -- uncomment the line with `socket' on it.
3) run `configure --enable-static'
4) run `make'
5) use the resulting libruby-static.a archive to build Lich.

If things didn't go well and/or you didn't get a libruby-static archive, refer
to Ruby's documentation.
