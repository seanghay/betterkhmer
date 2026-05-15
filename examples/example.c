#include <stdio.h>
#include <stdlib.h>
#include "betterkhmer.h"

int main(void) {
    const char *text = "\xe1\x9e\x81\xe1\x9f\x92\xe1\x9e\x98\xe1\x9f\x82\xe1\x9e\x9a"; /* ខ្មែរ */
    char *result = normalize(text, "km");
    printf("%s\n", result);
    free(result);
    return 0;
}
