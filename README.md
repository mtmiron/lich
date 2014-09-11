# Compiling the application



### The dependency on Ruby's library.

* go to http://www.ruby-lang.org and download Ruby's sourcecode.
* unpack it someplace and edit the file *./ext/Setup* -- uncomment the line with *socket* on it.
* run *configure --enable-static*
* run *make*
* use the resulting *libruby-static.a* archive to build Lich.

If things didn't go well and/or you didn't get a libruby-static archive, refer
to Ruby's documentation.
