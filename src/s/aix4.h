#define AIX4

#include "aix3-2-5.h"

/* AIX 4 does not have HFT any more.  */
#undef AIXHFT

#ifndef NOT_C_CODE
#define _XFUNCS_H_ 1

/* AIX is happier when bzero and strcasecmp are declared */
#include "strings.h"

/* AIX 4.2's sys/mman.h doesn't seem to define MAP_FAILED,
   although Unix98 claims it must. */
#ifdef HAVE_MMAP
#include <sys/mman.h>
# ifndef MAP_FAILED
#  define MAP_FAILED ((void *) -1)
# endif
#endif

/* Forward declarations for xlc warning suppressions */
struct ether_addr;
struct sockaddr_dl;
#endif /* C code */
