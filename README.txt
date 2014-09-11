The files "libsocket.a" and "libruby-static.a" were compiled for i686-Linux, and if you're unable to use them, you'll need to build ones for your own system.  Here's how:

1) go to http://www.ruby-lang.org and download Ruby's sourcecode (v1.8.4 is known to work).
2) unpack it someplace and edit the file `./ext/Setup' -- uncomment the line with `socket' on it.
3) run `./configure --enable-static'
4) run `make'

If everything went well, then just copy the files './libruby-static.a' and `./ext/socket/socket.a' to the Lich source directory (and name the latter `libsocket.a') and `make' Lich.

If things didn't go well, refer to Ruby's documentation for what to do in order to build the libraries.
