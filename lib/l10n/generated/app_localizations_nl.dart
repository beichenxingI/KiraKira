import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Dutch Flemish (`nl`).
class AppLocalizationsNl extends AppLocalizations {
  AppLocalizationsNl([String locale = 'nl']) : super(locale);

  @override
  String get appTitle => 'KiraKira';

  @override
  String get home => 'Home';

  @override
  String get characters => 'Personages';

  @override
  String get settings => 'Instellingen';

  @override
  String get chats => 'Chats';

  @override
  String get newChat => 'Nieuwe Chat';

  @override
  String get noChatsYet => 'Nog geen chats';

  @override
  String get startNewConversation => 'Start een gesprek met een personage';

  @override
  String get browseCharacters => 'Blader door Personages';

  @override
  String get groupChats => 'Groepschats';

  @override
  String get import => 'Importeren';

  @override
  String get delete => 'Verwijderen';

  @override
  String get cancel => 'Annuleren';

  @override
  String get save => 'Opslaan';

  @override
  String get edit => 'Bewerken';

  @override
  String get copy => 'Kopiëren';

  @override
  String get retry => 'Opnieuw';

  @override
  String get close => 'Sluiten';

  @override
  String get ok => 'OK';

  @override
  String get yes => 'Ja';

  @override
  String get no => 'Nee';

  @override
  String get loading => 'Laden...';

  @override
  String get error => 'Fout';

  @override
  String errorLoadingChats(Object error) {
    return 'Fout bij laden van chats: $error';
  }

  @override
  String get deleteChat => 'Chat Verwijderen';

  @override
  String get deleteChatConfirmation => 'Weet je zeker dat je deze chat wilt verwijderen? Deze actie kan niet ongedaan worden gemaakt.';

  @override
  String get chatDeleted => 'Chat verwijderd';

  @override
  String get yesterday => 'Gisteren';

  @override
  String daysAgo(Object count) {
    return '$count dagen geleden';
  }

  @override
  String get noMessages => 'Geen berichten';

  @override
  String get noMessagesYet => 'Nog geen berichten';

  @override
  String get chat => 'Chat';

  @override
  String get typeMessage => 'Typ een bericht...';

  @override
  String get send => 'Verzenden';

  @override
  String get regenerate => 'Regenereren';

  @override
  String get continueGeneration => 'Doorgaan';

  @override
  String get viewCharacter => 'Bekijk Personage';

  @override
  String get authorsNote => 'Auteursnotitie';

  @override
  String get bookmarks => 'Bladwijzers';

  @override
  String get exportChat => 'Chat Exporteren';

  @override
  String get importChat => 'Chat Importeren';

  @override
  String get clearMessages => 'Berichten Wissen';

  @override
  String get selectModel => 'Selecteer Model';

  @override
  String get loadingModels => 'Modellen laden...';

  @override
  String get noModelsAvailable => 'Geen modellen beschikbaar. Controleer je API-instellingen.';

  @override
  String modelChangedTo(Object model) {
    return 'Model gewijzigd naar $model';
  }

  @override
  String failedToLoadModels(Object error) {
    return 'Kon modellen niet laden: $error';
  }

  @override
  String get searchModels => 'Zoek modellen...';

  @override
  String get noModelsMatchSearch => 'Geen overeenkomende modellen';

  @override
  String get provider => 'Provider';

  @override
  String get apiNotConfigured => 'API Niet Geconfigureerd';

  @override
  String get apiNotConfiguredMessage => 'Om met personages te chatten, moet je eerst een LLM-provider configureren.';

  @override
  String get supportedProviders => 'Ondersteunde providers:';

  @override
  String get configureNow => 'Nu Configureren';

  @override
  String get later => 'Later';

  @override
  String get configure => 'Configureren';

  @override
  String get configureApiProvider => 'Configureer LLM-provider om te beginnen met chatten';

  @override
  String get startConversation => 'Start Gesprek';

  @override
  String get deleteMessage => 'Bericht Verwijderen';

  @override
  String get deleteMessageConfirmation => 'Weet je zeker dat je dit bericht wilt verwijderen?';

  @override
  String get deleteMessages => 'Berichten Verwijderen';

  @override
  String get deleteMessagesConfirmation => 'Weet je zeker dat je dit bericht en alle volgende berichten wilt verwijderen?';

  @override
  String get deleteAll => 'Alles Verwijderen';

  @override
  String get copiedToClipboard => 'Gekopieerd naar klembord';

  @override
  String get generateNewResponse => 'Genereer nieuw antwoord';

  @override
  String get continueFromHere => 'Ga verder vanaf hier';

  @override
  String get deleteMessagesAfterAndRegenerate => 'Verwijder berichten hierna en regenereer';

  @override
  String get deleteMessagesAfterThis => 'Verwijder alle berichten hierna';

  @override
  String get createBookmark => 'Bladwijzer Maken';

  @override
  String get saveAsCheckpoint => 'Sla dit punt op als checkpoint';

  @override
  String get deleteThisMessage => 'Verwijder dit bericht';

  @override
  String get deleteThisAndAllAfter => 'Verwijder dit en alle volgende';

  @override
  String get attachImage => 'Afbeelding Bijvoegen';

  @override
  String get formatting => '格式化';

  @override
  String get chooseFromGallery => 'Kies uit Galerij';

  @override
  String get takePhoto => 'Foto Maken';

  @override
  String failedToPickImage(Object error) {
    return 'Kon afbeelding niet selecteren: $error';
  }

  @override
  String failedToTakePhoto(Object error) {
    return 'Kon foto niet maken: $error';
  }

  @override
  String failedToAddAttachment(Object error) {
    return 'Kon bijlage niet toevoegen: $error';
  }

  @override
  String exportChatWith(Object character) {
    return 'Exporteer chat met $character';
  }

  @override
  String messagesCount(Object count) {
    return '$count berichten';
  }

  @override
  String get chooseExportFormat => 'Kies exportformaat:';

  @override
  String get json => 'JSON';

  @override
  String get jsonlStFormat => 'JSONL (ST-formaat)';

  @override
  String get noChatToExport => 'Geen chat om te exporteren';

  @override
  String exportFailed(Object error) {
    return 'Export mislukt: $error';
  }

  @override
  String get importChatHistory => 'Importeer chatgeschiedenis uit bestand';

  @override
  String get supportedFormats => 'Ondersteunde formaten:';

  @override
  String get jsonlSillyTavernFormat => 'JSONL (SillyTavern-formaat)';

  @override
  String get jsonNativeTavernFormat => 'JSON (NativeTavern-formaat)';

  @override
  String get importNote => 'Opmerking: Geïmporteerde berichten worden toegevoegd aan de huidige chat.';

  @override
  String get chooseFile => 'Kies Bestand';

  @override
  String get noFileSelected => 'Geen bestand geselecteerd of ongeldig formaat';

  @override
  String get importConfirmation => 'Importbevestiging';

  @override
  String get character => 'Personage';

  @override
  String get user => 'Gebruiker';

  @override
  String get messages => 'Berichten';

  @override
  String get date => 'Datum';

  @override
  String get hasAuthorsNote => 'Heeft auteursnotitie';

  @override
  String get importMessagesToCurrentChat => 'Deze berichten importeren naar huidige chat?';

  @override
  String get noActiveChat => 'Geen actieve chat';

  @override
  String importedMessages(Object count) {
    return '$count berichten succesvol geïmporteerd';
  }

  @override
  String importFailed(Object error) {
    return 'Import mislukt: $error';
  }

  @override
  String get clearMessagesConfirmation => 'Weet je zeker dat je alle berichten wilt wissen? Deze actie kan niet ongedaan worden gemaakt.';

  @override
  String get clear => 'Wissen';

  @override
  String get thinking => 'Denken';

  @override
  String get noSwipesAvailable => 'Geen swipes beschikbaar';

  @override
  String get system => 'Systeem';

  @override
  String get backgroundFeatureComingSoon => 'Achtergrondfunctie binnenkort beschikbaar';

  @override
  String get authorsNoteUpdated => 'Auteursnotitie bijgewerkt';

  @override
  String get commandError => 'Commandofout';

  @override
  String get enabled => 'Ingeschakeld';

  @override
  String get disabled => 'Uitgeschakeld';

  @override
  String get personas => 'Persona\'s';

  @override
  String get createPersona => 'Persona Maken';

  @override
  String get editPersona => 'Persona Bewerken';

  @override
  String get deletePersona => 'Persona Verwijderen';

  @override
  String deletePersonaConfirmation(Object name) {
    return 'Weet je zeker dat je \"$name\" wilt verwijderen?';
  }

  @override
  String get noPersonasYet => 'Nog geen persona\'s';

  @override
  String get createPersonaDescription => 'Maak een persona om jezelf te vertegenwoordigen in chats';

  @override
  String get name => 'Naam';

  @override
  String get enterPersonaName => 'Voer personanaam in';

  @override
  String get description => 'Beschrijving';

  @override
  String get describePersona => 'Beschrijf deze persona (optioneel)';

  @override
  String get personaDescriptionHelp => 'De beschrijving wordt opgenomen in de systeemprompt om de AI te helpen begrijpen wie je bent.';

  @override
  String get pleaseEnterName => 'Voer een naam in';

  @override
  String get default_ => 'Standaard';

  @override
  String get active => 'Actief';

  @override
  String get setAsDefault => 'Instellen als Standaard';

  @override
  String get removeAvatar => 'Avatar Verwijderen';

  @override
  String failedToSaveAvatar(Object error) {
    return 'Kon avatar niet opslaan: $error';
  }

  @override
  String get selectAvatarImage => 'Selecteer avatarafbeelding';

  @override
  String get aiConfiguration => 'AI-configuratie';

  @override
  String get llmProvider => 'LLM-provider';

  @override
  String get apiUrl => 'API-URL';

  @override
  String get apiKey => 'API-sleutel';

  @override
  String get model => 'Model';

  @override
  String get temperature => 'Temperatuur';

  @override
  String get maxTokens => 'Maximum Tokens';

  @override
  String get topP => 'Top P';

  @override
  String get topK => 'Top K';

  @override
  String get frequencyPenalty => 'Frequentiepenalty';

  @override
  String get presencePenalty => 'Aanwezigheidspenalty';

  @override
  String get repetitionPenalty => 'Herhalingspenalty';

  @override
  String get streamingEnabled => 'Streaming Ingeschakeld';

  @override
  String get testConnection => 'Test Verbinding';

  @override
  String get connectionSuccessful => 'Verbinding succesvol!';

  @override
  String connectionFailed(Object error) {
    return 'Verbinding mislukt: $error';
  }

  @override
  String get openai => 'OpenAI';

  @override
  String get claude => 'Claude';

  @override
  String get openRouter => 'OpenRouter';

  @override
  String get gemini => 'Gemini';

  @override
  String get ollama => 'Ollama';

  @override
  String get koboldCpp => 'KoboldCpp';

  @override
  String get local => 'Lokaal';

  @override
  String get aiPresets => 'AI-presets';

  @override
  String get createPreset => 'Preset Maken';

  @override
  String get editPreset => 'Preset Bewerken';

  @override
  String get deletePreset => 'Preset Verwijderen';

  @override
  String get presetName => 'Presetnaam';

  @override
  String get promptManager => 'Promptbeheer';

  @override
  String get systemPrompt => 'Systeemprompt';

  @override
  String get jailbreak => 'Jailbreak';

  @override
  String get worldInfo => 'Wereldinfo';

  @override
  String get createEntry => 'Item Maken';

  @override
  String get editEntry => 'Item Bewerken';

  @override
  String get deleteEntry => 'Item Verwijderen';

  @override
  String get keywords => 'Trefwoorden';

  @override
  String get content => 'Inhoud';

  @override
  String get priority => 'Prioriteit';

  @override
  String get groups => 'Groepen';

  @override
  String get createGroup => 'Groep Maken';

  @override
  String get editGroup => 'Groep Bewerken';

  @override
  String get deleteGroup => 'Groep Verwijderen';

  @override
  String get groupName => 'Groepsnaam';

  @override
  String get members => 'Leden';

  @override
  String get addMember => 'Lid Toevoegen';

  @override
  String get removeMember => 'Lid Verwijderen';

  @override
  String get tags => 'Tags';

  @override
  String get createTag => 'Tag Maken';

  @override
  String get editTag => 'Tag Bewerken';

  @override
  String get deleteTag => 'Tag Verwijderen';

  @override
  String get tagName => 'Tagnaam';

  @override
  String get color => 'Kleur';

  @override
  String get quickReplies => 'Snelle Antwoorden';

  @override
  String get createQuickReply => 'Snel Antwoord Maken';

  @override
  String get editQuickReply => 'Snel Antwoord Bewerken';

  @override
  String get deleteQuickReply => 'Snel Antwoord Verwijderen';

  @override
  String get label => 'Label';

  @override
  String get message => 'Bericht';

  @override
  String get autoSend => 'Automatisch Verzenden';

  @override
  String get regex => 'Regex';

  @override
  String get createRegex => 'Regex maken';

  @override
  String get editRegex => 'Regex bewerken';

  @override
  String get deleteRegex => 'Regex verwijderen';

  @override
  String get pattern => 'Patroon';

  @override
  String get replacement => 'Vervanging';

  @override
  String get backup => 'Back-up';

  @override
  String get backupSubtitle => '本地和云端备份与恢复';

  @override
  String get createBackup => 'Back-up Maken';

  @override
  String get restoreBackup => 'Back-up Herstellen';

  @override
  String get backupCreated => 'Back-up succesvol gemaakt';

  @override
  String get backupRestored => 'Back-up succesvol hersteld';

  @override
  String backupFailed(Object error) {
    return 'Back-up mislukt: $error';
  }

  @override
  String restoreFailed(Object error) {
    return 'Herstel mislukt: $error';
  }

  @override
  String get theme => 'Thema';

  @override
  String get darkMode => 'Donkere Modus';

  @override
  String get lightMode => 'Lichte Modus';

  @override
  String get systemTheme => 'Volg Systeem';

  @override
  String get primaryColor => 'Primaire Kleur';

  @override
  String get accentColor => 'Accentkleur';

  @override
  String get advanced => 'Geavanceerd';

  @override
  String get advancedSettings => 'Geavanceerde Instellingen';

  @override
  String get statistics => 'Statistieken';

  @override
  String get totalChats => 'Totaal Chats';

  @override
  String get totalMessages => 'Totaal Berichten';

  @override
  String get totalCharacters => 'Totaal Personages';

  @override
  String get tokenizer => 'Tokenizer';

  @override
  String get tts => 'Tekst-naar-Spraak';

  @override
  String get stt => 'Spraak-naar-Tekst';

  @override
  String get translation => 'Vertaling';

  @override
  String get imageGeneration => 'Afbeelding Genereren';

  @override
  String get vectorStorage => 'Vectoropslag';

  @override
  String get sprites => 'Sprites';

  @override
  String get backgrounds => 'Achtergronden';

  @override
  String get cfgScale => 'CFG-schaal';

  @override
  String get logitBias => 'Logit Bias';

  @override
  String get variables => 'Variabelen';

  @override
  String get listView => 'Lijstweergave';

  @override
  String get gridView => 'Rasterweergave';

  @override
  String get search => 'Zoeken';

  @override
  String get searchCharacters => 'Zoek personages...';

  @override
  String get noCharactersFound => 'Geen personages gevonden';

  @override
  String get noCharactersYet => 'Nog geen personages';

  @override
  String get importCharacter => 'Importeer een personage om te beginnen';

  @override
  String get createCharacter => 'Personage Maken';

  @override
  String get editCharacter => 'Personage Bewerken';

  @override
  String get deleteCharacter => 'Personage Verwijderen';

  @override
  String deleteCharacterConfirmation(Object name) {
    return 'Weet je zeker dat je \"$name\" wilt verwijderen? Alle chats met dit personage worden ook verwijderd.';
  }

  @override
  String get characterDeleted => 'Personage verwijderd';

  @override
  String get startChat => 'Start Chat';

  @override
  String get personality => 'Persoonlijkheid';

  @override
  String get scenario => 'Scenario';

  @override
  String get firstMessage => 'Eerste Bericht';

  @override
  String get exampleDialogue => 'Voorbeelddialoog';

  @override
  String get creatorNotes => 'Makernotities';

  @override
  String get alternateGreetings => 'Alternatieve Begroetingen';

  @override
  String get characterBook => 'Personageboek';

  @override
  String get language => 'Taal';

  @override
  String get selectLanguage => 'Selecteer Taal';

  @override
  String get languageChanged => 'Taal gewijzigd';

  @override
  String get about => 'Over';

  @override
  String get version => 'Versie';

  @override
  String get licenses => 'Licenties';

  @override
  String get privacyPolicy => 'Privacybeleid';

  @override
  String get termsOfService => 'Servicevoorwaarden';

  @override
  String get feedback => 'Feedback';

  @override
  String get rateApp => 'Beoordeel App';

  @override
  String get shareApp => 'Deel App';

  @override
  String get checkForUpdates => 'Controleer op Updates';

  @override
  String get noUpdatesAvailable => 'Geen updates beschikbaar';

  @override
  String get updateAvailable => 'Update beschikbaar';

  @override
  String get downloadUpdate => 'Download Update';

  @override
  String get bookmarkCreated => 'Bladwijzer gemaakt';

  @override
  String get bookmarkName => 'Bladwijzernaam';

  @override
  String get enterBookmarkName => 'Voer bladwijzernaam in';

  @override
  String get noBookmarksYet => 'Nog geen bladwijzers';

  @override
  String get createBookmarkDescription => 'Maak bladwijzers om belangrijke punten in het gesprek op te slaan';

  @override
  String get jumpToBookmark => 'Ga naar Bladwijzer';

  @override
  String get deleteBookmark => 'Bladwijzer Verwijderen';

  @override
  String get bookmarkDeleted => 'Bladwijzer verwijderd';

  @override
  String get saveAsJsonl => 'Opslaan als JSONL';

  @override
  String get saveAsJson => 'Opslaan als JSON';

  @override
  String get keyboardShortcuts => 'Sneltoetsen:';

  @override
  String get bold => 'Vet';

  @override
  String get italic => 'Cursief';

  @override
  String get underline => 'Onderstrepen';

  @override
  String get strikethrough => 'Doorhalen';

  @override
  String get inlineCode => 'Inline Code';

  @override
  String get link => 'Link';

  @override
  String get slashCommands => 'Slash-commando\'s';

  @override
  String get availableCommands => 'Beschikbare commando\'s:';

  @override
  String get commandHelp => 'Typ / om beschikbare commando\'s te zien';

  @override
  String get debugLog => '调试日志';

  @override
  String get debugLogDescription => '显示悬浮调试按钮以查看日志';

  @override
  String get autoScroll => '自动滚动';

  @override
  String get clearLogs => '清除日志';

  @override
  String get searchLogs => '搜索日志...';

  @override
  String get noLogsYet => '暂无日志';

  @override
  String get contextManagement => '上下文管理';

  @override
  String get autoSummarize => '自动总结';

  @override
  String get autoSummarizeDescription => '当上下文使用率较高时自动总结并压缩聊天历史';

  @override
  String get autoSummarizeThreshold => '自动总结阈值';

  @override
  String get autoSummarizeThresholdDescription => '当上下文达到最大值的此百分比时触发总结';

  @override
  String get allCharactersAvailable => '所有角色';

  @override
  String get availableToAllCharactersNotGlobal => '所有角色可用（上下文匹配）';

  @override
  String get specificCharacter => '特定角色';

  @override
  String get linkToSpecificCharacter => '仅关联到特定角色';

  @override
  String get selectCharacter => '选择角色';

  @override
  String get noCharactersAvailable => '暂无可用角色';

  @override
  String get pleaseSelectCharacter => '请选择一个角色';

  @override
  String get contextUsage => '上下文使用';

  @override
  String get totalTokens => '总令牌数';

  @override
  String get maxContext => '最大上下文';

  @override
  String get remaining => '剩余';

  @override
  String get breakdown => '详细分解';

  @override
  String get cloudBackup => '云备份';

  @override
  String get cloudBackupInfo => '云备份';

  @override
  String get cloudBackupDescription => '跨设备同步数据';

  @override
  String get cloudBackupSubtitle => '备份到 iCloud 或 Google Drive，在任何设备上恢复';

  @override
  String get enableICloudBackup => '启用 iCloud 备份';

  @override
  String get enableICloudBackupDescription => '自动同步备份到 iCloud';

  @override
  String get iCloudNotAvailable => 'iCloud 不可用';

  @override
  String get iCloudNotAvailableDescription => '请在设置中登录 iCloud';

  @override
  String get backupToICloud => '备份到 iCloud';

  @override
  String lastSync(Object time) {
    return '上次同步：$time';
  }

  @override
  String get neverSynced => '从未同步';

  @override
  String get iCloudBackups => 'iCloud 备份';

  @override
  String get noCloudBackups => '暂无云备份';

  @override
  String get googleDriveExport => '导出到 Google Drive';

  @override
  String get googleDriveExportDescription => '保存备份文件到 Google Drive 或其他位置';

  @override
  String get googleDriveImport => '从 Google Drive 导入';

  @override
  String get googleDriveImportDescription => '从 Google Drive 或其他位置恢复备份文件';

  @override
  String get export => '导出';

  @override
  String get import_action => '导入';

  @override
  String get importBackup => '导入备份';

  @override
  String get backupExported => '备份导出成功';

  @override
  String get restoreSettings => '恢复设置';

  @override
  String get defaultRestoreMode => '默认恢复模式';

  @override
  String get selectRestoreMode => '选择数据恢复方式：';

  @override
  String get restoreWarning => '根据所选模式，恢复数据可能会覆盖现有数据。请确保先备份当前数据。';

  @override
  String get restore => '恢复';

  @override
  String restoreComplete(Object added, Object skipped, Object updated) {
    return '恢复完成：新增 $added 项，更新 $updated 项，跳过 $skipped 项';
  }

  @override
  String get selectFileAndImport => '选择文件并导入';

  @override
  String get aboutRestoreModes => '关于恢复模式';

  @override
  String get aboutRestoreModesDescription => '替换：用备份数据覆盖所有本地数据。\\n合并：保留两者，冲突时新数据优先。\\n仅添加新项：仅从备份添加新项，保留所有现有数据。';

  @override
  String get backupAndRestore => '备份与恢复';

  @override
  String get refresh => '刷新';

  @override
  String get storage => '存储';

  @override
  String get totalBackupSize => '备份总大小';

  @override
  String get calculating => '计算中...';

  @override
  String get lastAutoBackup => '上次自动备份';

  @override
  String get autoBackup => '自动备份';

  @override
  String get enableAutoBackup => '启用自动备份';

  @override
  String get automaticallyBackupChats => '自动备份聊天记录';

  @override
  String get backupInterval => '备份间隔';

  @override
  String get backupOnExit => '退出时备份';

  @override
  String get createBackupWhenClosingApp => '关闭应用时创建备份';

  @override
  String get retention => '保留策略';

  @override
  String get maxChatBackups => '最大聊天备份数';

  @override
  String keepUpToChatBackups(Object count) {
    return '最多保留 $count 个聊天备份';
  }

  @override
  String get maxFullBackups => '最大完整备份数';

  @override
  String keepUpToFullBackups(Object count) {
    return '最多保留 $count 个完整备份';
  }

  @override
  String get cleanupOldBackups => '清理旧备份';

  @override
  String get deleteBackupsExceedingLimits => '删除超过限制的备份';

  @override
  String get cleanup => '清理';

  @override
  String deletedOldBackups(Object count) {
    return '已删除 $count 个旧备份';
  }

  @override
  String get chatBackups => '聊天备份';

  @override
  String get noChatBackups => '暂无聊天备份';

  @override
  String viewAllBackups(Object count) {
    return '查看全部 $count 个备份';
  }

  @override
  String get fullBackups => '完整备份';

  @override
  String get noFullBackups => '暂无完整备份';

  @override
  String get information => '信息';

  @override
  String get aboutBackups => '关于备份';

  @override
  String get aboutBackupsDescription => '聊天备份保存单个对话。完整备份包含所有角色、聊天、设置和世界信息。';

  @override
  String get backupLocation => '备份位置';

  @override
  String errorReadingBackup(Object error) {
    return '读取备份错误：$error';
  }

  @override
  String get deleteBackup => '删除备份';

  @override
  String deleteBackupConfirmation(Object name) {
    return '删除 \"$name\"？\\n\\n此操作无法撤销。';
  }

  @override
  String get view => '查看';

  @override
  String get justNow => '刚刚';

  @override
  String minutesAgo(Object count) {
    return '$count 分钟前';
  }

  @override
  String hoursAgo(Object count) {
    return '$count 小时前';
  }

  @override
  String get processing => '处理中...';

  @override
  String get signInToGoogleDrive => '登录 Google Drive';

  @override
  String get signInToGoogleDriveDescription => '使用 Google 账户登录以备份和恢复数据';

  @override
  String get signIn => '登录';

  @override
  String get signOut => '退出登录';

  @override
  String get signedInSuccessfully => '登录成功';

  @override
  String get backupToGoogleDrive => '备份到 Google Drive';

  @override
  String get googleDriveBackups => 'Google Drive 备份';

  @override
  String get saveAs => '保存';

  @override
  String get contextLength => '文本';

  @override
  String get contextWindowSize => '文本';

  @override
  String get contextLengthDescription => '模型';

  @override
  String get characterNotFound => '角色';

  @override
  String get characterNotFoundMessage => '角色';

  @override
  String get exportAsPng => '导出为PNG图片卡';

  @override
  String get exportAsCharx => '导出为CharX';

  @override
  String get exportAsJson => '导出为JSON';

  @override
  String get duplicate => '复制角色';

  @override
  String deleteCharacterConfirmationSimple(Object name) {
    return '删除';
  }

  @override
  String characterDuplicated(Object name) {
    return '名称';
  }

  @override
  String failedToDelete(Object error) {
    return '删除';
  }

  @override
  String failedToDuplicate(Object error) {
    return '错误';
  }

  @override
  String get pngExportComingSoon => '导出';

  @override
  String get charxExportComingSoon => '导出';

  @override
  String get failedToCreateChat => '聊天';

  @override
  String get creating => '创建中...';

  @override
  String byCreator(Object creator) {
    return '由 $creator 创建';
  }

  @override
  String versionLabel(Object version) {
    return 'v$version';
  }

  @override
  String get showLess => '显示';

  @override
  String get showMore => '显示';

  @override
  String greetingNumber(Object number) {
    return '数字';
  }

  @override
  String alternateGreetingsCount(Object count) {
    return '计数';
  }

  @override
  String get embeddedLorebook => '内嵌世界书';

  @override
  String entriesEnabled(Object enabled, Object total) {
    return '启用';
  }

  @override
  String andMoreEntries(Object count) {
    return '计数';
  }

  @override
  String get exampleMessages => '消息';

  @override
  String get postHistoryInstructions => '历史后指令';

  @override
  String get selectImages => '图像';

  @override
  String get presetsAndTemplates => '预设';

  @override
  String get activePreset => '预设';

  @override
  String get change => '更改';

  @override
  String get noPresetSelected => '预设';

  @override
  String get instructTemplate => '指令模板';

  @override
  String get selectInstructTemplate => '选择';

  @override
  String get instructTemplateDescription => '模型';

  @override
  String get orderAndTogglePromptSections => '提示';

  @override
  String get llmConnection => 'LLM 连接';

  @override
  String get generationSettings => '设置';

  @override
  String get advancedSamplerSettings => '设置';

  @override
  String get fullControlOverSampling => '完全控制采样参数';

  @override
  String get selectLlmProvider => '选择';

  @override
  String get notSet => '未设置';

  @override
  String get enterApiKey => '输入你的 API 密钥';

  @override
  String get apiEndpointUrl => 'API 端点地址';

  @override
  String get modelName => '模型';

  @override
  String get fetchAvailableModels => '模型';

  @override
  String get fetchModelsDescription => '模型';

  @override
  String get enterModelName => '模型';

  @override
  String get fetchingModels => '模型';

  @override
  String get failedToFetchModels => '模型';

  @override
  String get tapToTestConnection => '测试';

  @override
  String get testing => '测试';

  @override
  String get connected => '已连接';

  @override
  String get connectionFailedSimple => '失败';

  @override
  String get maximumTokensToGenerate => '令牌';

  @override
  String get streaming => '流式输出';

  @override
  String get showResponseAsItGenerates => '显示';

  @override
  String selectModelCount(Object count) {
    return '模型';
  }

  @override
  String get refreshModels => '模型';

  @override
  String get enterManually => '手动';

  @override
  String get noModelsFound => '模型';

  @override
  String get tryDifferentSearchTerm => '搜索';

  @override
  String modelsOfTotal(Object filtered, Object total) {
    return '模型';
  }

  @override
  String get importPreset => '预设';

  @override
  String get noGroupChatsYet => '聊天';

  @override
  String get createGroupDescription => '角色';

  @override
  String get newGroup => '新建群组';

  @override
  String membersAndMode(Object count, Object mode) {
    return '模式';
  }

  @override
  String get groupChatWillBeImplemented => '聊天';

  @override
  String deleteGroupConfirmation(Object name) {
    return '聊天';
  }

  @override
  String groupDeleted(Object name) {
    return '删除';
  }

  @override
  String get groupNameRequired => '名称';

  @override
  String get enterGroupName => '名称';

  @override
  String get optionalDescription => '描述';

  @override
  String get selectCharacters => '角色';

  @override
  String charactersSelected(Object count) {
    return '角色';
  }

  @override
  String get create => '创建';

  @override
  String get selectAtLeast2Characters => '角色';

  @override
  String get groupCreatedSuccessfully => '成功';

  @override
  String failedToCreateGroup(Object error) {
    return '错误';
  }

  @override
  String get selectCharacterCard => '角色';

  @override
  String get supportsPngCharxJson => '支持 PNG、CharX 和 JSON 格式';

  @override
  String get browseFiles => '文件';

  @override
  String failedToPickFile(Object error) {
    return '错误';
  }

  @override
  String failedToLoadCharacter(Object error) {
    return '角色';
  }

  @override
  String unsupportedFileFormat(Object format) {
    return '文件';
  }

  @override
  String get pngCharacterCard => '角色';

  @override
  String get characterDataEmbeddedInImage => '角色';

  @override
  String get charxArchive => 'CharX 压缩包';

  @override
  String get zipArchiveWithCharacterData => '角色';

  @override
  String get plainCharacterCardJson => '角色';

  @override
  String importedWithLorebook(Object name) {
    return '导入';
  }

  @override
  String importedSuccessfully(Object name) {
    return '导入';
  }

  @override
  String failedToImport(Object error) {
    return '导入';
  }

  @override
  String embeddedLorebookEntries(Object count) {
    return '计数';
  }

  @override
  String get saveCurrentAsPreset => '预设';

  @override
  String get exportCurrentSettings => '设置';

  @override
  String get builtInPresets => '预设';

  @override
  String get customPresets => '预设';

  @override
  String get aiPresetsDescription => '预设';

  @override
  String appliedPreset(Object name) {
    return '预设';
  }

  @override
  String failedToApplyPreset(Object error) {
    return '预设';
  }

  @override
  String get invalidPresetFormat => '预设';

  @override
  String importedAndApplied(Object name) {
    return '导入';
  }

  @override
  String get saveAsPreset => '预设';

  @override
  String get descriptionOptional => '描述';

  @override
  String get pleaseEnterAName => '名称';

  @override
  String savedPreset(Object name) {
    return '保存';
  }

  @override
  String saveFailed(Object error) {
    return '保存';
  }

  @override
  String deletePresetConfirmation(Object name) {
    return '删除';
  }

  @override
  String deletedPreset(Object name) {
    return '删除';
  }

  @override
  String get resetToDefaults => '重置';

  @override
  String get basicSampling => '基础采样';

  @override
  String get temperatureDescription => '控制随机性。越高越有创意，越低越专注。';

  @override
  String get topPNucleusSampling => 'Top P (核采样)';

  @override
  String get topPDescription => '令牌';

  @override
  String get topKDescription => '令牌';

  @override
  String get advancedSampling => '高级';

  @override
  String get minP => '最小';

  @override
  String get minPDescription => '令牌';

  @override
  String get typicalP => 'Typical P';

  @override
  String get typicalPDescription => '禁用';

  @override
  String get topA => '顶部';

  @override
  String get topADescription => '禁用';

  @override
  String get tailFreeSamplingTfs => '无尾采样 (TFS)';

  @override
  String get tfsDescription => '禁用';

  @override
  String get repetitionControl => '重复控制';

  @override
  String get repetitionPenaltyDescription => '令牌';

  @override
  String get repetitionPenaltyRange => '重复惩罚范围';

  @override
  String get repetitionPenaltyRangeDescription => '令牌';

  @override
  String get frequencyPenaltyDescription => '令牌';

  @override
  String get presencePenaltyDescription => '令牌';

  @override
  String get mirostatLocalModels => '模型';

  @override
  String get mirostatMode => '模式';

  @override
  String get adaptiveSamplingForLocalModels => '模型';

  @override
  String get off => '关闭';

  @override
  String get mirostatTau => 'Mirostat Tau';

  @override
  String get mirostatTauDescription => '目标熵/困惑度。';

  @override
  String get mirostatEta => 'Mirostat Eta';

  @override
  String get mirostatEtaDescription => '比率';

  @override
  String get generationControl => '生成';

  @override
  String get maxTokensDescription => '令牌';

  @override
  String get seed => '种子';

  @override
  String get seedDescription => '用于可复现的随机种子。-1 = 随机。';

  @override
  String get stopSequences => '顶部';

  @override
  String get noStopSequencesConfigured => '配置';

  @override
  String get stopSequencesDescription => '生成';

  @override
  String get resetConfirmation => '设置';

  @override
  String get reset => '重置';

  @override
  String get settingsResetToDefaults => '设置';

  @override
  String get characterBackground => '角色';

  @override
  String get chatBackground => '聊天';

  @override
  String get clearBackground => '清除';

  @override
  String get gradientPresets => '预设';

  @override
  String get solidColors => '纯色';

  @override
  String get customImage => '图像';

  @override
  String get adjustments => '调整';

  @override
  String get noBackgroundSelected => '选择';

  @override
  String get chooseImage => '图像';

  @override
  String get fromUrl => '来自 URL';

  @override
  String localImage(Object filename) {
    return '名称';
  }

  @override
  String urlLabel(Object url) {
    return 'URL: $url';
  }

  @override
  String get noImage => '图像';

  @override
  String get opacity => '透明度';

  @override
  String get blurEffect => '模糊效果';

  @override
  String get applyBlurToBackground => '应用';

  @override
  String get blurAmount => '模糊程度';

  @override
  String failedToLoadImage(Object error) {
    return '加载';
  }

  @override
  String get imageUrl => '图像';

  @override
  String get enterImageUrl => '图像';

  @override
  String get apply => '应用';

  @override
  String get enableCfgScale => '启用';

  @override
  String get cfgScaleDescription => '文本';

  @override
  String get globalSettings => '设置';

  @override
  String get guidanceScale => '引导系数';

  @override
  String get negativePrompt => '提示';

  @override
  String get textToSteerAwayFrom => '模型';

  @override
  String get positivePromptOptional => '提示';

  @override
  String get textToEnhanceInOutput => '文本';

  @override
  String get characterSettings => '角色';

  @override
  String get useCharacterSpecificSettings => '角色';

  @override
  String get overrideGlobalForCharacter => '角色';

  @override
  String get characterNegativePrompt => '角色';

  @override
  String get overrideGlobalNegativePrompt => '提示';

  @override
  String get chatSettings => '聊天';

  @override
  String get chatSettingsDescription => '角色';

  @override
  String get chatNegativePrompt => '聊天';

  @override
  String get overrideForThisChat => '聊天';

  @override
  String get chatPositivePrompt => '聊天';

  @override
  String get enhancementForThisChat => '聊天';

  @override
  String get promptCombineMode => '提示';

  @override
  String get replaceChatPromptOnly => '聊天';

  @override
  String get prependChatPlusGlobal => '聊天';

  @override
  String get appendGlobalPlusChat => '聊天';

  @override
  String get aboutCfgScale => '关于 CFG Scale';

  @override
  String get aboutCfgScaleDescription => '模型';

  @override
  String get cfgScaleHelp => '帮助';

  @override
  String get cfgScaleHelpContent => '角色';

  @override
  String get help => '帮助';

  @override
  String get sampleMessage1 => '你好！最近怎么样？';

  @override
  String get sampleMessage2 => '我很好！';

  @override
  String get general => '通用';

  @override
  String get enableImageGeneration => '图像';

  @override
  String get generateImagesUsingAi => '图像';

  @override
  String get imageGenerationProvider => '图像';

  @override
  String get apiEndpoint => 'API 端点';

  @override
  String get notConfigured => '配置';

  @override
  String get defaultParameters => '默认';

  @override
  String get imageSize => '图像';

  @override
  String get steps => '步数';

  @override
  String get sampler => '采样器';

  @override
  String get defaultNegativePrompt => '提示';

  @override
  String get enterTermsToAvoid => '图像';

  @override
  String get test => '测试';

  @override
  String get aboutImageGeneration => '图像';

  @override
  String get aboutImageGenerationDescription => '角色';

  @override
  String get imagineCommand => '/imagine 命令';

  @override
  String get imagineCommandUsage => '提示';

  @override
  String get stableDiffusion => 'Stable Diffusion';

  @override
  String get stableDiffusionDescription => '启用';

  @override
  String get dalle => 'DALL-E';

  @override
  String get dalleDescription => '图像';

  @override
  String get prompt => '提示';

  @override
  String get enterPromptToGenerate => '提示';

  @override
  String get generate => '比率';

  @override
  String get generating => '生成中...';

  @override
  String get generationComplete => '完成';

  @override
  String get imageWouldBeDisplayed => '图像';

  @override
  String get enableLogitBias => '启用';

  @override
  String get adjustTokenProbabilities => '令牌';

  @override
  String get presets => '预设';

  @override
  String get activePresetLabel => '预设';

  @override
  String get none => '无';

  @override
  String get newPreset => '预设';

  @override
  String get importPresetLabel => '预设';

  @override
  String get biasEntries => '偏置条目';

  @override
  String get noBiasEntries => '暂无偏置条目';

  @override
  String get addEntriesToAdjust => '令牌';

  @override
  String get addEntry => '添加';

  @override
  String get textOrToken => '令牌';

  @override
  String textTokenHint(Object verbatim) {
    return '单词、$verbatim 或 [1234]';
  }

  @override
  String get bias => '偏置';

  @override
  String get logitBiasHelp => '帮助';

  @override
  String get presetCopiedToClipboard => '预设';

  @override
  String exportPresetFailed(Object error) {
    return '导出';
  }

  @override
  String get pastePresetJson => '预设';

  @override
  String get presetImportedSuccessfully => '预设';

  @override
  String importPresetFailed(Object error) {
    return '导入';
  }

  @override
  String get rename => '名称';

  @override
  String get deletePresetQuestion => '预设';

  @override
  String get moreOptions => '更多选项';

  @override
  String get loadPreset => '预设';

  @override
  String get saveAsPresetLabel => '预设';

  @override
  String get exportPreset => '预设';

  @override
  String get resetToDefault => '重置';

  @override
  String get dragToReorder => '向量检索';

  @override
  String deleted(Object name) {
    return '删除';
  }

  @override
  String imported(Object name) {
    return '导入';
  }

  @override
  String get invalidPresetFormatMessage => '预设';

  @override
  String get exportPresetTitle => '预设';

  @override
  String get presetNameLabel => '预设';

  @override
  String get pleaseEnterNameMessage => '名称';

  @override
  String saved(Object name) {
    return '保存';
  }

  @override
  String saveFailedMessage(Object error) {
    return '保存';
  }

  @override
  String get resetToDefaultQuestion => '重置';

  @override
  String get resetToDefaultConfig => '重置';

  @override
  String get promptManagerHelp => '帮助';

  @override
  String applied(Object name) {
    return '预设';
  }

  @override
  String get showQuickReplies => '显示';

  @override
  String get displayQuickReplyButtons => '聊天';

  @override
  String get positionAboveInput => '位置';

  @override
  String get quickRepliesAboveInput => '字段';

  @override
  String get quickRepliesBelowInput => '字段';

  @override
  String get add => '添加';

  @override
  String get noQuickReplies => '暂无快捷回复';

  @override
  String get addYourFirstQuickReply => '添加';

  @override
  String deleteQuickReplyQuestion(Object label) {
    return '删除';
  }

  @override
  String get resetToDefaultQuestion2 => '默认';

  @override
  String get continueOrEmpty => '消息';

  @override
  String get autoSendTooltip => '自动';

  @override
  String get addQuickReply => '添加';

  @override
  String get editQuickReplyLabel => '编辑';

  @override
  String get buttonLabel => '标签';

  @override
  String get buttonLabelHint => '例如：是、继续、思考...';

  @override
  String get messageLabel => '消息';

  @override
  String get leaveEmptyForContinue => '留空表示继续操作';

  @override
  String supportsMacros(Object char, Object user) {
    return '宏';
  }

  @override
  String get autoSendLabel => '自动';

  @override
  String get messageSentImmediately => '消息';

  @override
  String get messageFillsInput => '消息';

  @override
  String get regexScripts => '正则表达式';

  @override
  String get addScript => '添加';

  @override
  String get addPresets => '预设';

  @override
  String get clearAll => '清除';

  @override
  String get enableRegexScripts => '正则表达式';

  @override
  String get applyFindReplacePatterns => '应用';

  @override
  String get applyTo => '应用';

  @override
  String get userInput => '输入';

  @override
  String get applyBeforeSending => '应用';

  @override
  String get aiOutput => '输出';

  @override
  String get applyToAiResponses => '应用';

  @override
  String get slashCommandsLabel => '斜杠命令';

  @override
  String get applyDuringCommandProcessing => '应用';

  @override
  String get worldInfoLabel => '世界';

  @override
  String get applyToWorldInfoEntries => '世界';

  @override
  String scriptsCount(Object count) {
    return '计数';
  }

  @override
  String get noRegexScripts => '正则表达式';

  @override
  String get tapToAddOrUseMenu => '预设';

  @override
  String get aboutRegexScripts => '正则表达式';

  @override
  String get aboutRegexScriptsDescription => '正则表达式';

  @override
  String get patternFormat => '模式格式';

  @override
  String get patternFormatDescription => '使用 /pattern/flags 格式（例如 /hello/gi）或纯文本模式。标志：i=忽略大小写，m=多行，s=点匹配全部';

  @override
  String get presetScriptsAdded => '预设';

  @override
  String deleteScriptQuestion(Object name) {
    return '删除';
  }

  @override
  String get clearAllScripts => '清除';

  @override
  String get clearAllScriptsQuestion => '正则表达式';

  @override
  String get importScripts => '导入';

  @override
  String get pasteJsonArray => '粘贴脚本的 JSON 数组';

  @override
  String importedCount(Object count) {
    return '导入';
  }

  @override
  String get exportScripts => '导出';

  @override
  String get newScript => '新建脚本';

  @override
  String get editScript => '编辑';

  @override
  String get scriptName => '名称';

  @override
  String get descriptionOptionalLabel => '描述';

  @override
  String get findPattern => '查找模式';

  @override
  String get patternOrPlainPattern => '/pattern/flags 或纯文本模式';

  @override
  String get replaceWith => '替换为';

  @override
  String get useCaptureGroups => '使用 \$1、\$2 表示捕获组';

  @override
  String get applyToLabel => '应用';

  @override
  String get options => '选项';

  @override
  String get markdownOnly => '仅 Markdown';

  @override
  String get onlyApplyDuringMarkdown => '应用';

  @override
  String get promptOnly => '提示';

  @override
  String get onlyApplyDuringPrompt => '应用';

  @override
  String get runOnEdit => '编辑';

  @override
  String get applyWhenEditingMessages => '编辑';

  @override
  String get macroSubstitution => '宏';

  @override
  String get nameAndPatternRequired => '名称';

  @override
  String get patternLabel => '模式';

  @override
  String get patternHint => '/pattern/flags';

  @override
  String get testString => '测试';

  @override
  String get replacementLabel => '替换内容';

  @override
  String replacementHint(Object match) {
    return '\$1、\$2、$match';
  }

  @override
  String get testButton => '测试';

  @override
  String matchesCount(Object count) {
    return '计数';
  }

  @override
  String get errorLabel => '错误';

  @override
  String get resultLabel => '结果';

  @override
  String get expressionSprites => '立绘';

  @override
  String get enableSprites => '启用';

  @override
  String get showCharacterExpressions => '角色';

  @override
  String get display => '显示';

  @override
  String get spriteSize => '立绘';

  @override
  String get position => '位置';

  @override
  String get whereToDisplaySprites => '立绘';

  @override
  String get left => '左侧';

  @override
  String get right => '右侧';

  @override
  String get center => '居中';

  @override
  String get floatingLeft => '左侧';

  @override
  String get floatingRight => '右侧';

  @override
  String get animation => '动画';

  @override
  String get animateTransitions => '过渡';

  @override
  String get smoothFadeWhenSpriteChanges => '立绘';

  @override
  String get transitionDuration => '持续时间';

  @override
  String get showDuringStreaming => '显示';

  @override
  String get displaySpritesWhileGenerating => '立绘';

  @override
  String get emotionDetection => '情绪';

  @override
  String get howItWorks => '工作原理';

  @override
  String get spriteEmotionDetectionDescription => '消息';

  @override
  String get supportedEmotions => '情绪';

  @override
  String characterSprites(Object name) {
    return '名称';
  }

  @override
  String get importFromFolder => '导入';

  @override
  String get deleteAllSprites => '删除';

  @override
  String get addSprite => '添加';

  @override
  String spritesCount(Object count) {
    return '立绘';
  }

  @override
  String defaultEmotion(Object emotion) {
    return '情绪';
  }

  @override
  String get noSpritesYet => '立绘';

  @override
  String get addExpressionImages => '角色';

  @override
  String get selectEmotion => '选择';

  @override
  String addedSpriteEmotion(Object emotion) {
    return '添加';
  }

  @override
  String get setAsDefaultEmotion => '默认';

  @override
  String get changeEmotion => '情绪';

  @override
  String get deleteSprite => '删除';

  @override
  String deleteSpriteConfirmation(Object emotion) {
    return '删除';
  }

  @override
  String get deleteAllSpritesConfirmation => '角色';

  @override
  String get importSprites => '导入';

  @override
  String get importSpritesDescription => '导入';

  @override
  String get supportedFormatsSprites => '支持的格式：PNG、JPG、GIF、WebP';

  @override
  String get selectFolder => '文件夹';

  @override
  String get folderImportRequiresPackage => '导入';

  @override
  String get appStatistics => '统计';

  @override
  String get chatStatistics => '聊天';

  @override
  String get resetStatistics => '重置';

  @override
  String get resetStatisticsConfirmation => '重置';

  @override
  String get statisticsReset => '重置';

  @override
  String get overview => '查看';

  @override
  String get firstUsed => '首次使用';

  @override
  String get unknown => '未知';

  @override
  String get totalGroups => '总计';

  @override
  String get totalGenerations => '生成';

  @override
  String get tokenUsage => '令牌';

  @override
  String get totalTokensUsed => '令牌';

  @override
  String get avgTokensPerGeneration => '令牌';

  @override
  String get performance => '性能';

  @override
  String get totalGenerationTime => '生成';

  @override
  String get avgGenerationTime => '生成';

  @override
  String get userMessages => '消息';

  @override
  String get assistantMessages => '消息';

  @override
  String get systemMessages => '消息';

  @override
  String get timeline => '时间线';

  @override
  String get firstMessage_ => '消息';

  @override
  String get lastMessage => '消息';

  @override
  String get chatDuration => '聊天';

  @override
  String get promptTokens => '令牌';

  @override
  String get completionTokens => '令牌';

  @override
  String get avgTokensPerMessage => '令牌';

  @override
  String get generationPerformance => '生成';

  @override
  String get generationCount => '生成';

  @override
  String get speechToText => '文本';

  @override
  String get enableStt => '启用';

  @override
  String get useVoiceInputForMessages => '语音';

  @override
  String get autoSendStt => '自动';

  @override
  String get automaticallySendAfterSpeaking => '消息';

  @override
  String get continuousListening => '列表';

  @override
  String get keepListeningAfterPhrase => '列表';

  @override
  String get showPartialResults => '显示';

  @override
  String get displayTextAsYouSpeak => '文本';

  @override
  String get sttProvider => '语音识别服务商';

  @override
  String get recognitionLanguage => '语言';

  @override
  String get testVoiceInput => '测试';

  @override
  String get stopListening => '列表';

  @override
  String get tapToStop => '顶部';

  @override
  String get tapToTestSpeechRecognition => '测试';

  @override
  String get final_ => '最终';

  @override
  String get listening => '列表';

  @override
  String get aboutStt => '关于 STT';

  @override
  String get aboutSttDescription => '聊天';

  @override
  String get systemStt => '系统';

  @override
  String get systemSttDescription => '设置';

  @override
  String get whisper => 'Whisper';

  @override
  String get whisperDescription => '模型';

  @override
  String get voiceInput => '语音';

  @override
  String get speechRecognitionNotAvailable => '识别';

  @override
  String get themes => '主题';

  @override
  String get createCustomTheme => '主题';

  @override
  String get builtInThemes => '主题';

  @override
  String get preview => '查看';

  @override
  String get chatPreview => '聊天';

  @override
  String get helloHowCanIHelp => '帮助';

  @override
  String get tellMeAStory => '给我讲个故事吧！';

  @override
  String get typeAMessage => '消息';

  @override
  String get createTheme => '主题';

  @override
  String get editTheme => '编辑';

  @override
  String get deleteTheme => '删除';

  @override
  String deleteThemeConfirmation(Object name) {
    return '删除';
  }

  @override
  String get themeName => '名称';

  @override
  String get background => '背景';

  @override
  String get surface => '表面';

  @override
  String get card => '卡片';

  @override
  String selectThemeColor(Object label) {
    return '选择';
  }

  @override
  String get hexColor => '十六进制颜色';

  @override
  String get tokenizerSettings => '令牌';

  @override
  String get tokenizerHelp => '帮助';

  @override
  String get tokenizerLabel => '令牌';

  @override
  String get showTokenCount => '令牌';

  @override
  String get displayTokenCountInInput => '聊天';

  @override
  String get showTokenVisualization => '令牌';

  @override
  String get highlightIndividualTokens => '令牌';

  @override
  String get cacheResults => '缓存';

  @override
  String get cacheTokenizationForPerformance => '令牌';

  @override
  String get tokenVisualization => '令牌';

  @override
  String get enterTextToTokenize => '令牌';

  @override
  String get typePasteTextHere => '文本';

  @override
  String get quickEstimate => '快速估算';

  @override
  String approximateTokens(Object count) {
    return '令牌';
  }

  @override
  String chars(Object count) {
    return '计数';
  }

  @override
  String get statisticsLabel => '统计';

  @override
  String get unique => '唯一';

  @override
  String get charsPerToken => '令牌';

  @override
  String get avgLength => '平均长度';

  @override
  String get longest => '最长';

  @override
  String get shortest => '测试';

  @override
  String get mostCommonTokens => '令牌';

  @override
  String get tokenBreakdown => '令牌';

  @override
  String tokensCount(Object count) {
    return '令牌';
  }

  @override
  String tokenIdLength(Object id, Object length) {
    return '令牌';
  }

  @override
  String get translationSettings => '翻译';

  @override
  String get enableTranslation => '启用';

  @override
  String get translateMessagesAutomatically => '消息';

  @override
  String get translationProvider => '翻译';

  @override
  String get sourceLanguage => '语言';

  @override
  String get targetLanguage => '语言';

  @override
  String get autoDetect => '自动';

  @override
  String get translateUserMessages => '消息';

  @override
  String get translateAiResponses => '翻译 AI 回复';

  @override
  String get textToSpeech => '文本';

  @override
  String get enableTts => '启用';

  @override
  String get readAiResponsesAloud => '朗读 AI 回复';

  @override
  String get ttsProvider => '语音合成服务商';

  @override
  String get voiceSettings => '设置';

  @override
  String get voice => '语音';

  @override
  String get speed => '速度';

  @override
  String get pitch => '音调';

  @override
  String get volume => '音量';

  @override
  String get autoPlay => '自动';

  @override
  String get automaticallyPlayResponses => '自动';

  @override
  String get testVoice => '测试';

  @override
  String get chatVariables => '聊天';

  @override
  String get variableSystem => '变量';

  @override
  String get globalVariables => '变量';

  @override
  String globalVariablesCount(Object count) {
    return '变量';
  }

  @override
  String get localVariables => '变量';

  @override
  String localVariablesCount(Object count) {
    return '变量';
  }

  @override
  String get addVariable => '添加';

  @override
  String get variableName => '名称';

  @override
  String get variableValue => '变量';

  @override
  String get scope => '作用域';

  @override
  String get global => '全局';

  @override
  String get vectorStorageRag => '向量检索';

  @override
  String get enableRag => '向量检索';

  @override
  String get useVectorStorageForContext => '向量检索';

  @override
  String get collections => '集合';

  @override
  String get createCollection => '创建';

  @override
  String get collectionName => '名称';

  @override
  String get embeddingProvider => '嵌入向量服务商';

  @override
  String get embeddingModel => '模型';

  @override
  String get chunkSize => '大小';

  @override
  String get chunkOverlap => '分块重叠';

  @override
  String get topKResults => '结果';

  @override
  String get similarityThreshold => '阈值';

  @override
  String get characterEditor => '角色';

  @override
  String get basic => '基础';

  @override
  String get prompts => '提示';

  @override
  String get meta => 'Meta';

  @override
  String get nameRequired => '名称';

  @override
  String get characterName => '角色';

  @override
  String get nameIsRequired => '名称';

  @override
  String get characterDescription => '角色';

  @override
  String get characterPersonalityTraits => '角色';

  @override
  String get currentCircumstancesContext => '文本';

  @override
  String get customInstructionsSystemMessage => '消息';

  @override
  String systemPromptHint(Object char) {
    return '你是 $char。你将...';
  }

  @override
  String get instructionsInsertedAfterHistory => '聊天';

  @override
  String postHistoryInstructionsHint(Object char) {
    return '以 $char 的身份继续角色扮演...';
  }

  @override
  String get firstMessageGreeting => '消息';

  @override
  String get firstMessageSentByCharacter => '角色';

  @override
  String firstMessageHint(Object user) {
    return '*走进房间* 你好，$user！';
  }

  @override
  String get alternateGreetingsCanSwipe => '消息';

  @override
  String greeting(Object index) {
    return '问候语 $index';
  }

  @override
  String get alternativeGreetingMessage => '消息';

  @override
  String get removeGreeting => '移除';

  @override
  String get moveUp => '上移';

  @override
  String get moveDown => '下移';

  @override
  String get noAlternateGreetings => '添加';

  @override
  String exampleDialogueDemonstrate(Object char, Object user) {
    return '角色';
  }

  @override
  String exampleMessagesHint(Object char, Object user) {
    return '<START>\\n$user: 你好吗？\\n$char: 我很好，谢谢关心！';
  }

  @override
  String get creatorNotesNotSentToAi => '角色';

  @override
  String get creatorNotesHint => '设置';

  @override
  String get tagsCommaSeparated => '比率';

  @override
  String get tagsHint => '奇幻、女性、冒险';

  @override
  String get creator => '创作者';

  @override
  String get yourNameOrUsername => '名称';

  @override
  String get versionNumber => '1.0.0';

  @override
  String get characterInfo => '角色';

  @override
  String characterId(Object id) {
    return 'ID: $id';
  }

  @override
  String created(Object date) {
    return '创建';
  }

  @override
  String modified(Object date) {
    return '修改于：$date';
  }

  @override
  String get characterSavedSuccessfully => '角色';

  @override
  String failedToSaveCharacter(Object error) {
    return '角色';
  }

  @override
  String get addAlternateGreeting => '添加';

  @override
  String get groupInfo => '信息';

  @override
  String get responseMode => '模式';

  @override
  String get howCharactersTakeTurns => '角色';

  @override
  String get sequential => '顺序';

  @override
  String get charactersRespondInOrder => '角色';

  @override
  String get random => '随机';

  @override
  String get randomCharacterResponds => '角色';

  @override
  String get allAtOnce => '一次全部';

  @override
  String get allNonMutedCharactersRespond => '角色';

  @override
  String get manual => '手动';

  @override
  String get youSelectWhoResponds => '角色';

  @override
  String get natural => '自然';

  @override
  String get aiDecidesBasedOnContext => '文本';

  @override
  String membersCount(Object count) {
    return '计数';
  }

  @override
  String get noMembersYet => '角色';

  @override
  String talkativenessPercent(Object percent) {
    return '健谈度：$percent%';
  }

  @override
  String triggers(Object words) {
    return '触发词：$words';
  }

  @override
  String get mute => '静音';

  @override
  String get unmute => '取消静音';

  @override
  String get memberSettings => '设置';

  @override
  String talkativenessLabel(Object percent) {
    return '健谈度：$percent%';
  }

  @override
  String get higherValuesMoreLikely => '角色';

  @override
  String get triggerWords => '触发词';

  @override
  String get triggerWordsHint => '词1、词2、词3';

  @override
  String get characterWillRespondWhenTriggered => '角色';

  @override
  String get addMemberToGroup => '添加';

  @override
  String get noMoreCharactersAvailable => '角色';

  @override
  String get groupSaved => '保存';

  @override
  String deleteGroupAndChats(Object name) {
    return '删除';
  }

  @override
  String get startChatAction => '聊天';

  @override
  String get noTagsYet => '暂无标签';

  @override
  String get createTagsToOrganize => '角色';

  @override
  String characterCount(Object count, Object plural) {
    return '角色';
  }

  @override
  String deleteTagConfirmation(Object name) {
    return '角色';
  }

  @override
  String get enterTagName => '名称';

  @override
  String get iconEmoji => '图标（表情符号）';

  @override
  String get enterEmojiOptional => '可选';

  @override
  String get pleaseEnterTagName => '名称';

  @override
  String get worldInfoLorebooks => '世界';

  @override
  String get createLorebook => '创建';

  @override
  String get noLorebooksYet => '暂无世界书';

  @override
  String get lorebooksInjectContext => '聊天';

  @override
  String entriesCount(Object count) {
    return '计数';
  }

  @override
  String deleteLorebookConfirmation(Object name) {
    return '删除';
  }

  @override
  String get enterLorebookName => '名称';

  @override
  String get optionalDescriptionHint => '描述';

  @override
  String get globalScope => '全局';

  @override
  String get applyToAllChats => '聊天';

  @override
  String get pleaseEnterName2 => '名称';

  @override
  String get noEntriesYet => '暂无条目';

  @override
  String get addEntriesWithKeywords => '聊天';

  @override
  String deleteEntryConfirmation(Object keys) {
    return '删除';
  }

  @override
  String get constant => '常驻';

  @override
  String get selective => '选择';

  @override
  String get keywordsCommaSeparated => '比率';

  @override
  String get keywordsHint => '向量检索';

  @override
  String get entryActivatesWhenKeywordFound => '聊天';

  @override
  String get secondaryKeysOptional => '可选';

  @override
  String get secondaryKeysHint => '火、火焰';

  @override
  String get bothPrimaryAndSecondaryMustMatch => '选择';

  @override
  String get commentOptional => '可选';

  @override
  String get noteForThisEntry => '此条目的备注';

  @override
  String get contentLabel => '内容';

  @override
  String get contextToInjectWhenMatches => '文本';

  @override
  String get pleaseEnterAtLeastOneKeyword => '请至少输入一个关键词';

  @override
  String get pleaseEnterContent => '内容';

  @override
  String get anthropic => 'Anthropic';

  @override
  String get cohere => 'Cohere';

  @override
  String get customProvider => '自定义';

  @override
  String get apiEndpointHint => 'https://api.example.com/v1';

  @override
  String get apiKeyHint => 'sk-...';

  @override
  String temperatureValue(Object value) {
    return '$value';
  }

  @override
  String maxTokensValue(Object value) {
    return '$value';
  }

  @override
  String topPValue(Object value) {
    return '$value';
  }

  @override
  String frequencyPenaltyValue(Object value) {
    return '$value';
  }

  @override
  String presencePenaltyValue(Object value) {
    return '$value';
  }

  @override
  String get streamResponse => '流式响应';

  @override
  String get streamTokensAsGenerated => '令牌';

  @override
  String get useSystemPrompt => '提示';

  @override
  String get includeSystemInstructions => '系统';

  @override
  String get configurationSavedSuccessfully => '保存';

  @override
  String get errorSavingConfiguration => '错误';

  @override
  String get copyAll => '复制';

  @override
  String get showFavoritesOnly => '显示';

  @override
  String get sortBy => '排序方式';

  @override
  String get filterByTags => '按标签筛选';

  @override
  String get favorites => '收藏';

  @override
  String get manage => '管理';

  @override
  String get noTagsCreatedYet => '创建';

  @override
  String get createTags => '创建';

  @override
  String charactersCount(num count) {
    return '角色';
  }

  @override
  String get characterTagsLegacy => '角色';

  @override
  String get done => '完成';

  @override
  String applyFiltersSelected(Object count) {
    return '应用';
  }

  @override
  String get enterPresetName => '预设';

  @override
  String get deleteScript => '删除';

  @override
  String get aiConfig => '配置';

  @override
  String get authorsNoteDescription => '文本';

  @override
  String get enableAuthorsNote => '启用';

  @override
  String get injectNoteIntoContext => '文本';

  @override
  String get injectionDepth => '注入深度';

  @override
  String get messagesFromEndWhereInserted => '消息';

  @override
  String get noteContent => '内容';

  @override
  String get authorsNoteHint => '角色';

  @override
  String get enterNameForCheckpoint => '名称';

  @override
  String get addDescription => '描述';

  @override
  String createCheckpointAtMessage(Object index) {
    return '消息';
  }

  @override
  String get longPressMessageToBookmark => '消息';

  @override
  String get branchFromBookmark => '从书签分支';

  @override
  String branchFromBookmarkWarning(Object name) {
    return '删除';
  }

  @override
  String get branch => '分支';

  @override
  String branchedFrom(Object name) {
    return '名称';
  }

  @override
  String deleteBookmarkConfirmation(Object name) {
    return '删除';
  }

  @override
  String messageIndexAndDate(Object date, Object index) {
    return '消息';
  }

  @override
  String get branchFromHere => '从此处分支';

  @override
  String previewBookmark(Object name) {
    return '名称';
  }

  @override
  String get messageNotFoundInChat => '聊天';

  @override
  String get you => '你';

  @override
  String get assistant => '助手';

  @override
  String get reasoningCopiedToClipboard => '推理内容已复制到剪贴板';

  @override
  String charsCount(Object count) {
    return '计数';
  }

  @override
  String get copyReasoning => '复制';

  @override
  String get commands => '命令';

  @override
  String aliasesLabel(Object aliases) {
    return '别名：$aliases';
  }

  @override
  String get noSpritesAddedYet => '添加';

  @override
  String get errorLoadingSprites => '加载';

  @override
  String get insertionPosition => '位置';

  @override
  String get beforeCharacterDefinition => '角色';

  @override
  String get afterCharacterDefinition => '角色';

  @override
  String get beforeExampleMessages => '消息';

  @override
  String get afterExampleMessages => '消息';

  @override
  String get beforeAuthorNote => '作者注释之前';

  @override
  String get afterAuthorNote => '作者注释之后';

  @override
  String get atDepth => '深度';

  @override
  String get beforeSystemPrompt => '提示';

  @override
  String get afterSystemPrompt => '提示';

  @override
  String get insertionOrder => '插入顺序';

  @override
  String get lowerOrderInsertsFirst => '数值越小越先插入';

  @override
  String get alwaysIncludeInPrompt => '提示';

  @override
  String get requiresSecondaryKey => '需同时匹配主关键词和次关键词';

  @override
  String get bubbleOpacity => '透明度';

  @override
  String get bubbleOpacityHelp => '消息';
}
