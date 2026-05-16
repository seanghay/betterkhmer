# betterkhmer · Python

Khmer Unicode normalizer.

Not published to a package registry — copy `python/betterkhmer/src/betterkhmer/__init__.py` into your project.

## Usage

```python
from betterkhmer import normalize

result = normalize("ខ្មែរ")
```

## Test

```bash
cd python/betterkhmer
pip install pytest
pytest tests/
```
