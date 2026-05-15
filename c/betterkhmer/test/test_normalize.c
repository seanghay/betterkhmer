#include "betterkhmer.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static char *read_line(FILE *f) {
    static char buf[65536];
    if (!fgets(buf, sizeof buf, f)) return NULL;
    size_t n = strlen(buf);
    while (n > 0 && (buf[n-1] == '\n' || buf[n-1] == '\r')) buf[--n] = '\0';
    return buf;
}

int main(int argc, char **argv) {
    const char *fixtures = argc > 1 ? argv[1] : "../../fixtures";

    /* basic test */
    /* ខ្មែរ = U+1781 U+17D2 U+1798 U+17C2 U+179A (5 chars, ~15 bytes) */
    char khmer[] = "\xe1\x9e\x81\xe1\x9f\x92\xe1\x9e\x98\xe1\x9f\x82\xe1\x9e\x9a";
    char *got = normalize(khmer, "km");
    if (strcmp(got, khmer) != 0) {
        fprintf(stderr, "basic FAILED\n"); free(got); return 1;
    }
    free(got);
    printf("basic: ok\n");

    /* fixture tests */
    char inp_path[4096], exp_path[4096];
    snprintf(inp_path, sizeof inp_path, "%s/input.txt",   fixtures);
    snprintf(exp_path, sizeof exp_path, "%s/expected.txt", fixtures);

    FILE *fi = fopen(inp_path, "r");
    FILE *fe = fopen(exp_path, "r");
    if (!fi || !fe) { fprintf(stderr, "cannot open fixtures\n"); return 1; }

    int total = 0, failures = 0;
    while (1) {
        char *in  = read_line(fi);
        char *ex  = read_line(fe);
        if (!in && !ex) break;
        if (!in || !ex) { fprintf(stderr, "length mismatch\n"); return 1; }

        char in_copy[65536];
        char ex_copy[65536];
        strncpy(in_copy, in, sizeof in_copy - 1); in_copy[sizeof in_copy - 1] = '\0';
        strncpy(ex_copy, ex, sizeof ex_copy - 1); ex_copy[sizeof ex_copy - 1] = '\0';

        char *result = normalize(in_copy, "km");
        if (strcmp(result, ex_copy) != 0) {
            failures++;
            if (failures <= 10)
                fprintf(stderr, "[%d] mismatch\n", total);
        }
        free(result);
        total++;
    }
    fclose(fi); fclose(fe);

    if (failures > 0) {
        fprintf(stderr, "%d/%d fixture failures\n", failures, total);
        return 1;
    }
    printf("fixtures: %d ok\n", total);
    return 0;
}
