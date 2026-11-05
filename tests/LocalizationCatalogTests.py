import collections
import json
import re
from pathlib import Path
catalog = json.loads(Path('ios/Sortyd/Localizable.xcstrings').read_text())['strings']
pattern = re.compile(r'%(?!%)(?:\d+\$)?[-+#0]*(?:\d+|\*)?(?:\.(?:\d+|\*))?(?:hh|ll|h|l|L|z|j|t)?[@diuoxXfFeEgGcsp]')
def placeholders(text):
    return collections.Counter(re.sub(r'^%(?:\d+\$)?', '%', token) for token in pattern.findall(text.replace('%%', '').replace('% Complete', ' Complete').replace('% completado', ' completado')))
count = 0
for key, entry in catalog.items():
    if not any(c.isalpha() for c in key):
        continue
    for language in ['ar', 'es', 'zh-Hans']:
        value = entry.get('localizations', {}).get(language, {}).get('stringUnit', {}).get('value')
        assert value and value.strip(), (key, language, 'missing translation')
        assert placeholders(key) == placeholders(value), (key, language, placeholders(key), placeholders(value))
        count += 1
print(f'Passed {count} translated strings and format contracts across Arabic, Spanish and Chinese')
