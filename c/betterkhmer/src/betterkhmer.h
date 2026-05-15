#ifndef BETTERKHMER_H
#define BETTERKHMER_H

/* Returns a newly-allocated, NUL-terminated UTF-8 string that is the
   Khmer-normalized form of txt.  Caller must free() the result.
   lang may be "km" (default) or "xhm". */
char *normalize(const char *txt, const char *lang);

#endif
