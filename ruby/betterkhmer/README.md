# betterkhmer · Ruby

Khmer Unicode normalizer.

Not published to a package registry — copy `ruby/betterkhmer/lib/betterkhmer.rb` into your project.

## Usage

```ruby
require 'betterkhmer'

result = BetterKhmer.normalize('ខ្មែរ')
```

## Test

```bash
cd ruby/betterkhmer
ruby spec/betterkhmer_spec.rb
```
