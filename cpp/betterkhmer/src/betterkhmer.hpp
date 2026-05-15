#pragma once
#include <string>

namespace betterkhmer {

/// Returns the Khmer-normalized form of txt.
std::string normalize(const std::string& txt, const std::string& lang = "km");

} // namespace betterkhmer
