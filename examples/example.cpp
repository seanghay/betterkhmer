#include <iostream>
#include "betterkhmer.hpp"

int main() {
    std::string text = "\xe1\x9e\x81\xe1\x9f\x92\xe1\x9e\x98\xe1\x9f\x82\xe1\x9e\x9a"; // ខ្មែរ
    std::string result = betterkhmer::normalize(text);
    std::cout << result << "\n";
    return 0;
}
