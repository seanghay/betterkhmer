-- Fixtures test for the betterkhmer Lua port.
-- Usage: lua test/fixtures.lua [fixtures_dir]

-- Make the module importable when run from lua/betterkhmer/.
-- Find the directory of this script via a plain reverse scan (no patterns).
local function script_dir(p)
  for i = #p, 1, -1 do
    local ch = p:sub(i, i)
    if ch == "/" or ch == "\\" then
      return p:sub(1, i)
    end
  end
  return "./"
end

local here = script_dir(arg[0])
local bk = dofile(here .. "../betterkhmer.lua")

local fixtures = arg[1] or (here .. "../../../fixtures")

-- basic test
local khmer = utf8.char(0x1781, 0x17D2, 0x1798, 0x17C2, 0x179A)
local got = bk.normalize(khmer)
if got ~= khmer then
  io.stderr:write("basic FAILED: got " .. got .. "\n")
  os.exit(1)
end
print("basic: ok")

local function read_lines(path)
  local f = assert(io.open(path, "rb"))
  local data = f:read("*a")
  f:close()
  local lines = {}
  local start = 1
  while true do
    local nl = data:find("\n", start, true)
    if not nl then
      if start <= #data then
        lines[#lines + 1] = data:sub(start)
      end
      break
    end
    lines[#lines + 1] = data:sub(start, nl - 1)
    start = nl + 1
  end
  -- Drop a trailing empty line caused by the final newline.
  if #lines > 0 and lines[#lines] == "" then
    lines[#lines] = nil
  end
  return lines
end

local inputs = read_lines(fixtures .. "/input.txt")
local expected = read_lines(fixtures .. "/expected.txt")

if #inputs ~= #expected then
  io.stderr:write("length mismatch: " .. #inputs .. " vs " .. #expected .. "\n")
  os.exit(1)
end

local failures = 0
for i = 1, #inputs do
  local result = bk.normalize(inputs[i])
  if result ~= expected[i] then
    failures = failures + 1
    if failures <= 10 then
      io.stderr:write(string.format("[%d] got %s, want %s\n",
        i - 1, result, expected[i]))
    end
  end
end

if failures > 0 then
  io.stderr:write(string.format("%d/%d fixture failures\n", failures, #inputs))
  os.exit(1)
end

print(string.format("fixtures: %d ok", #inputs))
