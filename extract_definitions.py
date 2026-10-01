import os
import re
import json
from pathlib import Path

lib_path = Path('lib')
dart_files = list(lib_path.rglob('*.dart'))

all_definitions = {}

for dart_file in dart_files:
    try:
        content = dart_file.read_text(encoding='utf-8')
    except:
        continue
    
    rel_path = str(dart_file.relative_to('.'))
    definitions = {
        'classes': [],
        'enums': [],
        'extensions': [],
        'mixins': [],
        'typedefs': [],
        'methods': [],
        'top_level_functions': []
    }
    
    # Classes (non-private)
    for match in re.finditer(r'^\s*class\s+([A-Z][a-zA-Z0-9_]*)', content, re.MULTILINE):
        definitions['classes'].append(match.group(1))
    
    # Enums
    for match in re.finditer(r'^\s*enum\s+([A-Z][a-zA-Z0-9_]*)', content, re.MULTILINE):
        definitions['enums'].append(match.group(1))
    
    # Extensions
    for match in re.finditer(r'^\s*extension\s+([A-Z][a-zA-Z0-9_]*)', content, re.MULTILINE):
        definitions['extensions'].append(match.group(1))
    
    # Mixins
    for match in re.finditer(r'^\s*mixin\s+([A-Z][a-zA-Z0-9_]*)', content, re.MULTILINE):
        definitions['mixins'].append(match.group(1))
    
    # Typedefs
    for match in re.finditer(r'^\s*typedef\s+([A-Z][a-zA-Z0-9_]*)', content, re.MULTILINE):
        definitions['typedefs'].append(match.group(1))
    
    # Methods/Functions
    for match in re.finditer(r'^\s*(?:Future|void|String|int|bool|List|Map|Set|Widget|FutureOr|Stream|dynamic|Object|num|double|Iterable)\s+([a-z][a-zA-Z0-9_]*)\s*\(', content, re.MULTILINE):
        definitions['methods'].append(match.group(1))
    
    # Getters/setters
    for match in re.finditer(r'^\s*(?:get|set)\s+([a-z][a-zA-Z0-9_]*)', content, re.MULTILINE):
        definitions['methods'].append(match.group(1))
    
    # Top-level functions
    lines = content.split('\n')
    in_class = False
    brace_count = 0
    for i, line in enumerate(lines):
        stripped = line.strip()
        if re.match(r'^\s*class\s+', stripped) or re.match(r'^\s*mixin\s+', stripped) or re.match(r'^\s*extension\s+', stripped):
            in_class = True
            brace_count = 0
        if in_class:
            brace_count += line.count('{') - line.count('}')
            if brace_count <= 0 and stripped and not stripped.startswith('//'):
                in_class = False
                brace_count = 0
        if not in_class and re.match(r'^\s*(?:Future|void|String|int|bool|List|Map|Set|Widget|FutureOr|Stream|dynamic|Object|num|double|Iterable)\s+([a-z][a-zA-Z0-9_]*)\s*\(', stripped):
            match = re.match(r'^\s*(?:Future|void|String|int|bool|List|Map|Set|Widget|FutureOr|Stream|dynamic|Object|num|double|Iterable)\s+([a-z][a-zA-Z0-9_]*)\s*\(', stripped)
            if match:
                definitions['top_level_functions'].append(match.group(1))
    
    # Deduplicate
    for key in definitions:
        definitions[key] = list(set(definitions[key]))
    
    if any(definitions.values()):
        all_definitions[rel_path] = definitions

# Write output
output_path = Path('DiaoYan/_all_definitions.json')
output_path.parent.mkdir(exist_ok=True)
output_path.write_text(json.dumps(all_definitions, indent=2, ensure_ascii=False), encoding='utf-8')
print(f'Written {len(all_definitions)} files to {output_path}')