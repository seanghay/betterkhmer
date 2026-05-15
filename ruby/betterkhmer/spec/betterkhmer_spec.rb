require_relative '../lib/betterkhmer'

ROOT = File.expand_path('../../..', __dir__)

def load_lines(path)
  File.read(path, encoding: 'UTF-8').lines.map { |l| l.chomp }
end

# Basic sanity check
raise "basic test failed" unless BetterKhmer.normalize('ខ្មែរ') == 'ខ្មែរ'
puts "basic: ok"

inputs   = load_lines(File.join(ROOT, 'fixtures', 'input.txt'))
expected = load_lines(File.join(ROOT, 'fixtures', 'expected.txt'))
raise "length mismatch" unless inputs.size == expected.size

failures = 0
inputs.each_with_index do |inp, i|
  got = BetterKhmer.normalize(inp)
  if got != expected[i]
    failures += 1
    puts "[#{i}] got #{got.inspect}, want #{expected[i].inspect}" if failures <= 10
  end
end
raise "#{failures}/#{inputs.size} fixture failures" if failures > 0
puts "fixtures: #{inputs.size} ok"
