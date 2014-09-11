#ifdef _WIN32
#	include "winrbconfig.h"
#	ifdef OS_CODE
#		undef OS_CODE
#	endif
/*
#	define RUBY_EXPORT
#	define HAVE_SOCKADDR_STORAGE
#	define HAVE_INET_NTOA
#	define HAVE_GETSERVBYPORT
#	define socklen_t=int
#	define HAVE_WSACLEANUP
#	define HAVE_GETHOSTNAME
*/
#else
#	include "rbconfig.h"
#endif
