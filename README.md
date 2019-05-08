# Lich
This is the first project I released publicly; started on it in 2005, and it was taken over by Tillmen in 2008 when my schoolwork became something I had to start paying actual attention to.  Had a couple hundred daily users at the time, which I still find pretty gratifying.



## Compiling the application
I was studying interpreters and Ruby in particular at the time, so half of it is written in C and half in Ruby.  The latest Ruby version at the time was 1.8.x, and the C API of later versions may not be compatible.


### The dependency on Ruby's library.

* go to http://www.ruby-lang.org and download Ruby's sourcecode.
* unpack it someplace and edit the file *./ext/Setup* -- uncomment the line with *socket* on it.
* run *configure --enable-static*
* run *make*
* use the resulting *libruby-static.a* archive to build Lich.

If things didn't go well and/or you didn't get a libruby-static archive, refer
to Ruby's documentation.
