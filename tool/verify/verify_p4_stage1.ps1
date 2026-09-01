$text = Get-Content -Raw -Encoding UTF8 'assets/chat/chat_stage.html'
$orbMarkers = 'kira-orb','__kiraOrb','data-orb-','orb.state','initKiraOrb','Kira Orb'
foreach ($marker in $orbMarkers) { if ($text.Contains($marker)) { throw "orb marker remains: $marker" } }
foreach ($marker in 'completion_prompt_manager_list','renderSections','pmSectionsChanged','prompt-manager-toggle-action') { if (-not $text.Contains($marker)) { throw "shadow DOM marker missing: $marker" } }
Write-Output 'STAGE1 STATIC VERIFY OK: orb markers absent; shadow DOM renderer and container retained'
