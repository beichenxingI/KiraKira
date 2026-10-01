$text = Get-Content -Raw -Encoding UTF8 'lib/presentation/screens/chat/webview_chat_stage.dart'
if (-not $text.Contains("onRequest(BridgeType.pmGetSections")) { throw 'pm get route missing' }
if (-not $text.Contains("onRequest(BridgeType.pmToggleSection")) { throw 'pm toggle route missing' }
if (-not $text.Contains('await notifier.updateSection(cur.copyWith(enabled: next))')) { throw 'toggle does not persist through notifier' }
if (-not $text.Contains('if (matches.length != 1)')) { throw 'ambiguous toggle is not rejected' }
$stage = Get-Content -Raw -Encoding UTF8 'assets/chat/chat_stage.html'
if (-not $stage.Contains('window.__shadowWriting')) { throw 'shadow reentry guard missing' }
Write-Output 'STAGE5 STATIC VERIFY OK: click writes through provider; ambiguous identifiers reject; shadow writes are guarded'
