import 'dart:io';
import 'dart:convert';

void main() async {
  final libDir = Directory('lib');
  final dartFiles = <File>[];
  
  await for (final entity in libDir.list(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      dartFiles.add(entity);
    }
  }
  
  print('Found ${dartFiles.length} Dart files');
  
  final allDefinitions = <String, Map<String, List<String>>>{};
  
  for (final dartFile in dartFiles) {
    final content = await dartFile.readAsString();
    final relPath = dartFile.path;
    
    final definitions = <String, List<String>>{
      'classes': <String>[],
      'enums': <String>[],
      'extensions': <String>[],
      'mixins': <String>[],
      'typedefs': <String>[],
      'methods': <String>[],
      'top_level_functions': <String>[],
    };
    
    // Classes (non-private)
    final classRegex = RegExp(r'^\s*class\s+([A-Z][a-zA-Z0-9_]*)', multiLine: true);
    for (final match in classRegex.allMatches(content)) {
      definitions['classes']!.add(match.group(1)!);
    }
    
    // Enums
    final enumRegex = RegExp(r'^\s*enum\s+([A-Z][a-zA-Z0-9_]*)', multiLine: true);
    for (final match in enumRegex.allMatches(content)) {
      definitions['enums']!.add(match.group(1)!);
    }
    
    // Extensions
    final extRegex = RegExp(r'^\s*extension\s+([A-Z][a-zA-Z0-9_]*)', multiLine: true);
    for (final match in extRegex.allMatches(content)) {
      definitions['extensions']!.add(match.group(1)!);
    }
    
    // Mixins
    final mixinRegex = RegExp(r'^\s*mixin\s+([A-Z][a-zA-Z0-9_]*)', multiLine: true);
    for (final match in mixinRegex.allMatches(content)) {
      definitions['mixins']!.add(match.group(1)!);
    }
    
    // Typedefs
    final typedefRegex = RegExp(r'^\s*typedef\s+([A-Z][a-zA-Z0-9_]*)', multiLine: true);
    for (final match in typedefRegex.allMatches(content)) {
      definitions['typedefs']!.add(match.group(1)!);
    }
    
    // Methods/Functions (simplified)
    final methodRegex = RegExp(r'^\s*(?:Future|void|String|int|bool|List|Map|Set|Widget|FutureOr|Stream|dynamic|Object|num|double|Iterable)\s+([a-z][a-zA-Z0-9_]*)\s*\(', multiLine: true);
    for (final match in methodRegex.allMatches(content)) {
      definitions['methods']!.add(match.group(1)!);
    }
    
    // Getters/setters
    final getterSetterRegex = RegExp(r'^\s*(?:get|set)\s+([a-z][a-zA-Z0-9_]*)', multiLine: true);
    for (final match in getterSetterRegex.allMatches(content)) {
      definitions['methods']!.add(match.group(1)!);
    }
    
    // Top-level functions (outside classes)
    final lines = content.split('\n');
    var inClass = false;
    var braceCount = 0;
    
    for (final line in lines) {
      final stripped = line.trim();
      
      if (RegExp(r'^\s*class\s+').hasMatch(stripped) || 
          RegExp(r'^\s*mixin\s+').hasMatch(stripped) || 
          RegExp(r'^\s*extension\s+').hasMatch(stripped)) {
        inClass = true;
        braceCount = 0;
      }
      
      if (inClass) {
        braceCount += '{'.allMatches(line).length - '}'.allMatches(line).length;
        if (braceCount <= 0 && stripped.isNotEmpty && !stripped.startsWith('//')) {
          inClass = false;
          braceCount = 0;
        }
      }
      
      if (!inClass) {
        final match = RegExp(r'^\s*(?:Future|void|String|int|bool|List|Map|Set|Widget|FutureOr|Stream|dynamic|Object|num|double|Iterable)\s+([a-z][a-zA-Z0-9_]*)\s*\(').firstMatch(stripped);
        if (match != null) {
          definitions['top_level_functions']!.add(match.group(1)!);
        }
      }
    }
    
    // Deduplicate
    for (final key in definitions.keys) {
      definitions[key] = definitions[key]!.toSet().toList();
    }
    
    if (definitions.values.any((v) => v.isNotEmpty)) {
      allDefinitions[relPath] = definitions;
    }
  }
  
  // Write output
  final outputFile = File('DiaoYan/_all_definitions.json');
  await outputFile.parent.create(recursive: true);
  await outputFile.writeAsString(const JsonEncoder.withIndent('  ').convert(allDefinitions));
  
  print('Written ${allDefinitions.length} files to ${outputFile.path}');
  
  // Print summary
  var totalClasses = 0, totalEnums = 0, totalExtensions = 0, totalMixins = 0, totalTypedefs = 0, totalMethods = 0, totalTopLevel = 0;
  for (final defs in allDefinitions.values) {
    totalClasses += (defs['classes'] as List).length;
    totalEnums += (defs['enums'] as List).length;
    totalExtensions += (defs['extensions'] as List).length;
    totalMixins += (defs['mixins'] as List).length;
    totalTypedefs += (defs['typedefs'] as List).length;
    totalMethods += (defs['methods'] as List).length;
    totalTopLevel += (defs['top_level_functions'] as List).length;
  }
  print('Summary:');
  print('  Classes: $totalClasses');
  print('  Enums: $totalEnums');
  print('  Extensions: $totalExtensions');
  print('  Mixins: $totalMixins');
  print('  Typedefs: $totalTypedefs');
  print('  Methods: $totalMethods');
  print('  Top-level functions: $totalTopLevel');
}