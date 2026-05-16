local betterkhmer = dofile("../lua/betterkhmer/betterkhmer.lua")

local text = "ខ្មែរ"
local result = betterkhmer.normalize(text)
print(result)
