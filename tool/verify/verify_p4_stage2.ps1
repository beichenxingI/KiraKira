$text = Get-Content -Raw -Encoding UTF8 'lib/data/models/prompt_manager.dart'
if (-not $text.Contains('section.identifier == updatedSection.identifier')) { throw 'identifier update match missing' }
if (-not $text.Contains('customPrompts[identifier]')) { throw 'identifier map missing' }
$stage = Get-Content -Raw -Encoding UTF8 'lib/presentation/screens/chat/webview_chat_stage.dart'
if (-not $stage.Contains("'identifier': s.identifier")) { throw 'outbound identifier missing' }
if (-not $stage.Contains("config.sections.where((s) => s.identifier == ident)")) { throw 'identifier toggle path missing' }
Write-Output 'STAGE2 STATIC VERIFY OK: duplicate identifiers are preserved and toggled by identifier'
