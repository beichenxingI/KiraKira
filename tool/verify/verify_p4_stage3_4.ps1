$text = Get-Content -Raw -Encoding UTF8 'lib/presentation/screens/chat/tavern_helper_facade.dart'
foreach ($marker in 'mvu.updateMode','mvu.autoRequest','mvu.maxChatHistory','mvu.apiUrl','_TH.getWorldbookNames','_TH.getWorldbook','_TH.replaceWorldbook') { if (-not $text.Contains($marker)) { throw "missing: $marker" } }
if ($text.Contains('getTavernRegexes=function(){return [];')) { throw 'regex missing-source must not return empty array' }
foreach ($marker in 'no Flutter data source','_TH.getTavernRegexes','_TH.updateTavernRegexesWith','_TH.getScriptTrees','_TH.updateScriptTreesWith') { if (-not $text.Contains($marker)) { throw "missing explicit failure: $marker" } }
Write-Output 'STAGE3-4 STATIC VERIFY OK: MVU values are interpolated from MvuSettings; unsupported APIs reject explicitly'
