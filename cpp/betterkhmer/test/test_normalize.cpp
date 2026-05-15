#include "betterkhmer.hpp"
#include <cstdio>
#include <cstring>
#include <fstream>
#include <string>

int main(int argc, char** argv) {
    const char* fixtures = argc > 1 ? argv[1] : "../../fixtures";

    // ខ្មែរ
    const std::string khmer = "\xe1\x9e\x81\xe1\x9f\x92\xe1\x9e\x98\xe1\x9f\x82\xe1\x9e\x9a";
    if (betterkhmer::normalize(khmer) != khmer) {
        std::fprintf(stderr, "basic FAILED\n"); return 1;
    }
    std::printf("basic: ok\n");

    char inp_path[4096], exp_path[4096];
    std::snprintf(inp_path, sizeof inp_path, "%s/input.txt",    fixtures);
    std::snprintf(exp_path, sizeof exp_path, "%s/expected.txt", fixtures);

    std::ifstream fi(inp_path), fe(exp_path);
    if (!fi || !fe) { std::fprintf(stderr, "cannot open fixtures\n"); return 1; }

    int total = 0, failures = 0;
    std::string in, ex;
    while (std::getline(fi, in) && std::getline(fe, ex)) {
        std::string result = betterkhmer::normalize(in);
        if (result != ex) {
            failures++;
            if (failures <= 10) std::fprintf(stderr, "[%d] mismatch\n", total);
        }
        total++;
    }

    if (failures > 0) {
        std::fprintf(stderr, "%d/%d fixture failures\n", failures, total);
        return 1;
    }
    std::printf("fixtures: %d ok\n", total);
    return 0;
}
