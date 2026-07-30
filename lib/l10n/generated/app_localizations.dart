import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_id.dart';
import 'app_localizations_it.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_ms.dart';
import 'app_localizations_nl.dart';
import 'app_localizations_pl.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_th.dart';
import 'app_localizations_tr.dart';
import 'app_localizations_vi.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('hi'),
    Locale('id'),
    Locale('it'),
    Locale('ja'),
    Locale('ko'),
    Locale('ms'),
    Locale('nl'),
    Locale('pl'),
    Locale('pt'),
    Locale('ru'),
    Locale('th'),
    Locale('tr'),
    Locale('vi'),
    Locale('zh'),
    Locale('zh', 'TW')
  ];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'KiraKira'**
  String get appTitle;

  /// No description provided for @home.
  ///
  /// In zh, this message translates to:
  /// **'首页'**
  String get home;

  /// No description provided for @characters.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get characters;

  /// No description provided for @settings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settings;

  /// No description provided for @chats.
  ///
  /// In zh, this message translates to:
  /// **'聊天'**
  String get chats;

  /// No description provided for @newChat.
  ///
  /// In zh, this message translates to:
  /// **'新建聊天'**
  String get newChat;

  /// No description provided for @noChatsYet.
  ///
  /// In zh, this message translates to:
  /// **'暂无聊天'**
  String get noChatsYet;

  /// No description provided for @startNewConversation.
  ///
  /// In zh, this message translates to:
  /// **'开始与角色对话'**
  String get startNewConversation;

  /// No description provided for @browseCharacters.
  ///
  /// In zh, this message translates to:
  /// **'浏览角色'**
  String get browseCharacters;

  /// No description provided for @groupChats.
  ///
  /// In zh, this message translates to:
  /// **'群聊'**
  String get groupChats;

  /// No description provided for @import.
  ///
  /// In zh, this message translates to:
  /// **'导入'**
  String get import;

  /// No description provided for @delete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get delete;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get save;

  /// No description provided for @edit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get edit;

  /// No description provided for @copy.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get copy;

  /// No description provided for @retry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get retry;

  /// No description provided for @close.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get close;

  /// No description provided for @ok.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get ok;

  /// No description provided for @yes.
  ///
  /// In zh, this message translates to:
  /// **'是'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In zh, this message translates to:
  /// **'否'**
  String get no;

  /// No description provided for @loading.
  ///
  /// In zh, this message translates to:
  /// **'加载中...'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In zh, this message translates to:
  /// **'错误'**
  String get error;

  /// No description provided for @errorLoadingChats.
  ///
  /// In zh, this message translates to:
  /// **'加载聊天失败：{error}'**
  String errorLoadingChats(Object error);

  /// No description provided for @deleteChat.
  ///
  /// In zh, this message translates to:
  /// **'删除聊天'**
  String get deleteChat;

  /// No description provided for @deleteChatConfirmation.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除此聊天吗？此操作无法撤销。'**
  String get deleteChatConfirmation;

  /// No description provided for @chatDeleted.
  ///
  /// In zh, this message translates to:
  /// **'聊天已删除'**
  String get chatDeleted;

  /// No description provided for @yesterday.
  ///
  /// In zh, this message translates to:
  /// **'昨天'**
  String get yesterday;

  /// No description provided for @daysAgo.
  ///
  /// In zh, this message translates to:
  /// **'{count}天前'**
  String daysAgo(Object count);

  /// No description provided for @noMessages.
  ///
  /// In zh, this message translates to:
  /// **'暂无消息'**
  String get noMessages;

  /// No description provided for @noMessagesYet.
  ///
  /// In zh, this message translates to:
  /// **'暂无消息'**
  String get noMessagesYet;

  /// No description provided for @chat.
  ///
  /// In zh, this message translates to:
  /// **'聊天'**
  String get chat;

  /// No description provided for @typeMessage.
  ///
  /// In zh, this message translates to:
  /// **'输入消息...'**
  String get typeMessage;

  /// No description provided for @send.
  ///
  /// In zh, this message translates to:
  /// **'发送'**
  String get send;

  /// No description provided for @regenerate.
  ///
  /// In zh, this message translates to:
  /// **'重新生成'**
  String get regenerate;

  /// No description provided for @continueGeneration.
  ///
  /// In zh, this message translates to:
  /// **'继续'**
  String get continueGeneration;

  /// No description provided for @viewCharacter.
  ///
  /// In zh, this message translates to:
  /// **'查看角色'**
  String get viewCharacter;

  /// No description provided for @authorsNote.
  ///
  /// In zh, this message translates to:
  /// **'作者注释'**
  String get authorsNote;

  /// No description provided for @bookmarks.
  ///
  /// In zh, this message translates to:
  /// **'书签'**
  String get bookmarks;

  /// No description provided for @exportChat.
  ///
  /// In zh, this message translates to:
  /// **'导出聊天'**
  String get exportChat;

  /// No description provided for @importChat.
  ///
  /// In zh, this message translates to:
  /// **'导入聊天'**
  String get importChat;

  /// No description provided for @clearMessages.
  ///
  /// In zh, this message translates to:
  /// **'清空消息'**
  String get clearMessages;

  /// No description provided for @selectModel.
  ///
  /// In zh, this message translates to:
  /// **'选择模型'**
  String get selectModel;

  /// No description provided for @loadingModels.
  ///
  /// In zh, this message translates to:
  /// **'加载模型中...'**
  String get loadingModels;

  /// No description provided for @noModelsAvailable.
  ///
  /// In zh, this message translates to:
  /// **'没有可用的模型。请检查API配置。'**
  String get noModelsAvailable;

  /// No description provided for @modelChangedTo.
  ///
  /// In zh, this message translates to:
  /// **'模型已切换为 {model}'**
  String modelChangedTo(Object model);

  /// No description provided for @failedToLoadModels.
  ///
  /// In zh, this message translates to:
  /// **'加载模型失败：{error}'**
  String failedToLoadModels(Object error);

  /// No description provided for @searchModels.
  ///
  /// In zh, this message translates to:
  /// **'搜索模型...'**
  String get searchModels;

  /// No description provided for @noModelsMatchSearch.
  ///
  /// In zh, this message translates to:
  /// **'没有匹配的模型'**
  String get noModelsMatchSearch;

  /// No description provided for @provider.
  ///
  /// In zh, this message translates to:
  /// **'提供商'**
  String get provider;

  /// No description provided for @apiNotConfigured.
  ///
  /// In zh, this message translates to:
  /// **'API未配置'**
  String get apiNotConfigured;

  /// No description provided for @apiNotConfiguredMessage.
  ///
  /// In zh, this message translates to:
  /// **'要与角色聊天，您需要先配置LLM提供商。'**
  String get apiNotConfiguredMessage;

  /// No description provided for @supportedProviders.
  ///
  /// In zh, this message translates to:
  /// **'支持的提供商：'**
  String get supportedProviders;

  /// No description provided for @configureNow.
  ///
  /// In zh, this message translates to:
  /// **'立即配置'**
  String get configureNow;

  /// No description provided for @later.
  ///
  /// In zh, this message translates to:
  /// **'稍后'**
  String get later;

  /// No description provided for @configure.
  ///
  /// In zh, this message translates to:
  /// **'配置'**
  String get configure;

  /// No description provided for @configureApiProvider.
  ///
  /// In zh, this message translates to:
  /// **'配置LLM提供商以开始聊天'**
  String get configureApiProvider;

  /// No description provided for @startConversation.
  ///
  /// In zh, this message translates to:
  /// **'开始对话'**
  String get startConversation;

  /// No description provided for @deleteMessage.
  ///
  /// In zh, this message translates to:
  /// **'删除消息'**
  String get deleteMessage;

  /// No description provided for @deleteMessageConfirmation.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除此消息吗？'**
  String get deleteMessageConfirmation;

  /// No description provided for @deleteMessages.
  ///
  /// In zh, this message translates to:
  /// **'删除消息'**
  String get deleteMessages;

  /// No description provided for @deleteMessagesConfirmation.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除此消息及之后的所有消息吗？'**
  String get deleteMessagesConfirmation;

  /// No description provided for @deleteAll.
  ///
  /// In zh, this message translates to:
  /// **'全部删除'**
  String get deleteAll;

  /// No description provided for @copiedToClipboard.
  ///
  /// In zh, this message translates to:
  /// **'已复制到剪贴板'**
  String get copiedToClipboard;

  /// No description provided for @generateNewResponse.
  ///
  /// In zh, this message translates to:
  /// **'生成新的回复'**
  String get generateNewResponse;

  /// No description provided for @continueFromHere.
  ///
  /// In zh, this message translates to:
  /// **'从此处继续'**
  String get continueFromHere;

  /// No description provided for @deleteMessagesAfterAndRegenerate.
  ///
  /// In zh, this message translates to:
  /// **'删除之后的消息并重新生成回复'**
  String get deleteMessagesAfterAndRegenerate;

  /// No description provided for @deleteMessagesAfterThis.
  ///
  /// In zh, this message translates to:
  /// **'删除此消息之后的所有消息'**
  String get deleteMessagesAfterThis;

  /// No description provided for @createBookmark.
  ///
  /// In zh, this message translates to:
  /// **'创建书签'**
  String get createBookmark;

  /// No description provided for @saveAsCheckpoint.
  ///
  /// In zh, this message translates to:
  /// **'将此处保存为检查点'**
  String get saveAsCheckpoint;

  /// No description provided for @deleteThisMessage.
  ///
  /// In zh, this message translates to:
  /// **'删除此消息'**
  String get deleteThisMessage;

  /// No description provided for @deleteThisAndAllAfter.
  ///
  /// In zh, this message translates to:
  /// **'删除此消息及之后的所有消息'**
  String get deleteThisAndAllAfter;

  /// No description provided for @attachImage.
  ///
  /// In zh, this message translates to:
  /// **'附加图片'**
  String get attachImage;

  /// No description provided for @formatting.
  ///
  /// In zh, this message translates to:
  /// **'格式化'**
  String get formatting;

  /// No description provided for @chooseFromGallery.
  ///
  /// In zh, this message translates to:
  /// **'从相册选择'**
  String get chooseFromGallery;

  /// No description provided for @takePhoto.
  ///
  /// In zh, this message translates to:
  /// **'拍照'**
  String get takePhoto;

  /// No description provided for @failedToPickImage.
  ///
  /// In zh, this message translates to:
  /// **'选择图片失败：{error}'**
  String failedToPickImage(Object error);

  /// No description provided for @failedToTakePhoto.
  ///
  /// In zh, this message translates to:
  /// **'拍照失败：{error}'**
  String failedToTakePhoto(Object error);

  /// No description provided for @failedToAddAttachment.
  ///
  /// In zh, this message translates to:
  /// **'添加附件失败：{error}'**
  String failedToAddAttachment(Object error);

  /// No description provided for @exportChatWith.
  ///
  /// In zh, this message translates to:
  /// **'导出与 {character} 的聊天'**
  String exportChatWith(Object character);

  /// No description provided for @messagesCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 条消息'**
  String messagesCount(Object count);

  /// No description provided for @chooseExportFormat.
  ///
  /// In zh, this message translates to:
  /// **'选择导出格式：'**
  String get chooseExportFormat;

  /// No description provided for @json.
  ///
  /// In zh, this message translates to:
  /// **'JSON'**
  String get json;

  /// No description provided for @jsonlStFormat.
  ///
  /// In zh, this message translates to:
  /// **'JSONL (ST格式)'**
  String get jsonlStFormat;

  /// No description provided for @noChatToExport.
  ///
  /// In zh, this message translates to:
  /// **'没有可导出的聊天'**
  String get noChatToExport;

  /// No description provided for @exportFailed.
  ///
  /// In zh, this message translates to:
  /// **'导出失败：{error}'**
  String exportFailed(Object error);

  /// No description provided for @importChatHistory.
  ///
  /// In zh, this message translates to:
  /// **'从文件导入聊天记录。'**
  String get importChatHistory;

  /// No description provided for @supportedFormats.
  ///
  /// In zh, this message translates to:
  /// **'支持的格式：'**
  String get supportedFormats;

  /// No description provided for @jsonlSillyTavernFormat.
  ///
  /// In zh, this message translates to:
  /// **'JSONL (SillyTavern格式)'**
  String get jsonlSillyTavernFormat;

  /// No description provided for @jsonNativeTavernFormat.
  ///
  /// In zh, this message translates to:
  /// **'JSON (NativeTavern格式)'**
  String get jsonNativeTavernFormat;

  /// No description provided for @importNote.
  ///
  /// In zh, this message translates to:
  /// **'注意：导入的消息将添加到当前聊天中。'**
  String get importNote;

  /// No description provided for @chooseFile.
  ///
  /// In zh, this message translates to:
  /// **'选择文件'**
  String get chooseFile;

  /// No description provided for @noFileSelected.
  ///
  /// In zh, this message translates to:
  /// **'未选择文件或格式无效'**
  String get noFileSelected;

  /// No description provided for @importConfirmation.
  ///
  /// In zh, this message translates to:
  /// **'导入确认'**
  String get importConfirmation;

  /// No description provided for @character.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get character;

  /// No description provided for @user.
  ///
  /// In zh, this message translates to:
  /// **'用户'**
  String get user;

  /// No description provided for @messages.
  ///
  /// In zh, this message translates to:
  /// **'消息'**
  String get messages;

  /// No description provided for @date.
  ///
  /// In zh, this message translates to:
  /// **'日期'**
  String get date;

  /// No description provided for @hasAuthorsNote.
  ///
  /// In zh, this message translates to:
  /// **'包含作者注释'**
  String get hasAuthorsNote;

  /// No description provided for @importMessagesToCurrentChat.
  ///
  /// In zh, this message translates to:
  /// **'将这些消息导入到当前聊天？'**
  String get importMessagesToCurrentChat;

  /// No description provided for @noActiveChat.
  ///
  /// In zh, this message translates to:
  /// **'没有活动的聊天'**
  String get noActiveChat;

  /// No description provided for @importedMessages.
  ///
  /// In zh, this message translates to:
  /// **'已导入 {count} 条消息'**
  String importedMessages(Object count);

  /// No description provided for @importFailed.
  ///
  /// In zh, this message translates to:
  /// **'导入失败：{error}'**
  String importFailed(Object error);

  /// No description provided for @clearMessagesConfirmation.
  ///
  /// In zh, this message translates to:
  /// **'确定要清空所有消息吗？此操作无法撤销。'**
  String get clearMessagesConfirmation;

  /// No description provided for @clear.
  ///
  /// In zh, this message translates to:
  /// **'清空'**
  String get clear;

  /// No description provided for @thinking.
  ///
  /// In zh, this message translates to:
  /// **'思考中'**
  String get thinking;

  /// No description provided for @noSwipesAvailable.
  ///
  /// In zh, this message translates to:
  /// **'没有可用的滑动'**
  String get noSwipesAvailable;

  /// No description provided for @system.
  ///
  /// In zh, this message translates to:
  /// **'系统'**
  String get system;

  /// No description provided for @backgroundFeatureComingSoon.
  ///
  /// In zh, this message translates to:
  /// **'背景功能即将推出'**
  String get backgroundFeatureComingSoon;

  /// No description provided for @authorsNoteUpdated.
  ///
  /// In zh, this message translates to:
  /// **'作者注释已更新'**
  String get authorsNoteUpdated;

  /// No description provided for @commandError.
  ///
  /// In zh, this message translates to:
  /// **'命令错误'**
  String get commandError;

  /// No description provided for @enabled.
  ///
  /// In zh, this message translates to:
  /// **'已启用'**
  String get enabled;

  /// No description provided for @disabled.
  ///
  /// In zh, this message translates to:
  /// **'已禁用'**
  String get disabled;

  /// No description provided for @personas.
  ///
  /// In zh, this message translates to:
  /// **'人设'**
  String get personas;

  /// No description provided for @createPersona.
  ///
  /// In zh, this message translates to:
  /// **'创建人设'**
  String get createPersona;

  /// No description provided for @editPersona.
  ///
  /// In zh, this message translates to:
  /// **'编辑人设'**
  String get editPersona;

  /// No description provided for @deletePersona.
  ///
  /// In zh, this message translates to:
  /// **'删除人设'**
  String get deletePersona;

  /// No description provided for @deletePersonaConfirmation.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除\"{name}\"吗？'**
  String deletePersonaConfirmation(Object name);

  /// No description provided for @noPersonasYet.
  ///
  /// In zh, this message translates to:
  /// **'暂无人设'**
  String get noPersonasYet;

  /// No description provided for @createPersonaDescription.
  ///
  /// In zh, this message translates to:
  /// **'创建人设以在聊天中代表自己'**
  String get createPersonaDescription;

  /// No description provided for @name.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get name;

  /// No description provided for @enterPersonaName.
  ///
  /// In zh, this message translates to:
  /// **'输入人设名称'**
  String get enterPersonaName;

  /// No description provided for @description.
  ///
  /// In zh, this message translates to:
  /// **'描述'**
  String get description;

  /// No description provided for @describePersona.
  ///
  /// In zh, this message translates to:
  /// **'描述此人设（可选）'**
  String get describePersona;

  /// No description provided for @personaDescriptionHelp.
  ///
  /// In zh, this message translates to:
  /// **'描述将包含在系统提示中，帮助AI了解您是谁。'**
  String get personaDescriptionHelp;

  /// No description provided for @pleaseEnterName.
  ///
  /// In zh, this message translates to:
  /// **'请输入名称'**
  String get pleaseEnterName;

  /// No description provided for @default_.
  ///
  /// In zh, this message translates to:
  /// **'默认'**
  String get default_;

  /// No description provided for @active.
  ///
  /// In zh, this message translates to:
  /// **'活动'**
  String get active;

  /// No description provided for @setAsDefault.
  ///
  /// In zh, this message translates to:
  /// **'设为默认'**
  String get setAsDefault;

  /// No description provided for @removeAvatar.
  ///
  /// In zh, this message translates to:
  /// **'移除头像'**
  String get removeAvatar;

  /// No description provided for @failedToSaveAvatar.
  ///
  /// In zh, this message translates to:
  /// **'保存头像失败：{error}'**
  String failedToSaveAvatar(Object error);

  /// No description provided for @selectAvatarImage.
  ///
  /// In zh, this message translates to:
  /// **'选择头像图片'**
  String get selectAvatarImage;

  /// No description provided for @aiConfiguration.
  ///
  /// In zh, this message translates to:
  /// **'AI配置'**
  String get aiConfiguration;

  /// No description provided for @llmProvider.
  ///
  /// In zh, this message translates to:
  /// **'LLM提供商'**
  String get llmProvider;

  /// No description provided for @apiUrl.
  ///
  /// In zh, this message translates to:
  /// **'API地址'**
  String get apiUrl;

  /// No description provided for @apiKey.
  ///
  /// In zh, this message translates to:
  /// **'API密钥'**
  String get apiKey;

  /// No description provided for @model.
  ///
  /// In zh, this message translates to:
  /// **'模型'**
  String get model;

  /// No description provided for @temperature.
  ///
  /// In zh, this message translates to:
  /// **'温度'**
  String get temperature;

  /// No description provided for @maxTokens.
  ///
  /// In zh, this message translates to:
  /// **'最大令牌数'**
  String get maxTokens;

  /// No description provided for @topP.
  ///
  /// In zh, this message translates to:
  /// **'Top P'**
  String get topP;

  /// No description provided for @topK.
  ///
  /// In zh, this message translates to:
  /// **'Top K'**
  String get topK;

  /// No description provided for @frequencyPenalty.
  ///
  /// In zh, this message translates to:
  /// **'频率惩罚'**
  String get frequencyPenalty;

  /// No description provided for @presencePenalty.
  ///
  /// In zh, this message translates to:
  /// **'存在惩罚'**
  String get presencePenalty;

  /// No description provided for @repetitionPenalty.
  ///
  /// In zh, this message translates to:
  /// **'重复惩罚'**
  String get repetitionPenalty;

  /// No description provided for @streamingEnabled.
  ///
  /// In zh, this message translates to:
  /// **'启用流式传输'**
  String get streamingEnabled;

  /// No description provided for @testConnection.
  ///
  /// In zh, this message translates to:
  /// **'测试连接'**
  String get testConnection;

  /// No description provided for @connectionSuccessful.
  ///
  /// In zh, this message translates to:
  /// **'连接成功！'**
  String get connectionSuccessful;

  /// No description provided for @connectionFailed.
  ///
  /// In zh, this message translates to:
  /// **'连接失败：{error}'**
  String connectionFailed(Object error);

  /// No description provided for @openai.
  ///
  /// In zh, this message translates to:
  /// **'OpenAI'**
  String get openai;

  /// No description provided for @claude.
  ///
  /// In zh, this message translates to:
  /// **'Claude'**
  String get claude;

  /// No description provided for @openRouter.
  ///
  /// In zh, this message translates to:
  /// **'OpenRouter'**
  String get openRouter;

  /// No description provided for @gemini.
  ///
  /// In zh, this message translates to:
  /// **'Gemini'**
  String get gemini;

  /// No description provided for @ollama.
  ///
  /// In zh, this message translates to:
  /// **'Ollama'**
  String get ollama;

  /// No description provided for @koboldCpp.
  ///
  /// In zh, this message translates to:
  /// **'KoboldCpp'**
  String get koboldCpp;

  /// No description provided for @local.
  ///
  /// In zh, this message translates to:
  /// **'本地'**
  String get local;

  /// No description provided for @aiPresets.
  ///
  /// In zh, this message translates to:
  /// **'AI预设'**
  String get aiPresets;

  /// No description provided for @createPreset.
  ///
  /// In zh, this message translates to:
  /// **'创建预设'**
  String get createPreset;

  /// No description provided for @editPreset.
  ///
  /// In zh, this message translates to:
  /// **'编辑预设'**
  String get editPreset;

  /// No description provided for @deletePreset.
  ///
  /// In zh, this message translates to:
  /// **'删除预设'**
  String get deletePreset;

  /// No description provided for @presetName.
  ///
  /// In zh, this message translates to:
  /// **'预设名称'**
  String get presetName;

  /// No description provided for @promptManager.
  ///
  /// In zh, this message translates to:
  /// **'提示词管理'**
  String get promptManager;

  /// No description provided for @systemPrompt.
  ///
  /// In zh, this message translates to:
  /// **'系统提示'**
  String get systemPrompt;

  /// No description provided for @jailbreak.
  ///
  /// In zh, this message translates to:
  /// **'越狱提示'**
  String get jailbreak;

  /// No description provided for @worldInfo.
  ///
  /// In zh, this message translates to:
  /// **'世界信息'**
  String get worldInfo;

  /// No description provided for @createEntry.
  ///
  /// In zh, this message translates to:
  /// **'创建条目'**
  String get createEntry;

  /// No description provided for @editEntry.
  ///
  /// In zh, this message translates to:
  /// **'编辑条目'**
  String get editEntry;

  /// No description provided for @deleteEntry.
  ///
  /// In zh, this message translates to:
  /// **'删除条目'**
  String get deleteEntry;

  /// No description provided for @keywords.
  ///
  /// In zh, this message translates to:
  /// **'关键词'**
  String get keywords;

  /// No description provided for @content.
  ///
  /// In zh, this message translates to:
  /// **'内容'**
  String get content;

  /// No description provided for @priority.
  ///
  /// In zh, this message translates to:
  /// **'优先级'**
  String get priority;

  /// No description provided for @groups.
  ///
  /// In zh, this message translates to:
  /// **'群组'**
  String get groups;

  /// No description provided for @createGroup.
  ///
  /// In zh, this message translates to:
  /// **'创建群组'**
  String get createGroup;

  /// No description provided for @editGroup.
  ///
  /// In zh, this message translates to:
  /// **'编辑群组'**
  String get editGroup;

  /// No description provided for @deleteGroup.
  ///
  /// In zh, this message translates to:
  /// **'删除群组'**
  String get deleteGroup;

  /// No description provided for @groupName.
  ///
  /// In zh, this message translates to:
  /// **'群组名称'**
  String get groupName;

  /// No description provided for @members.
  ///
  /// In zh, this message translates to:
  /// **'成员'**
  String get members;

  /// No description provided for @addMember.
  ///
  /// In zh, this message translates to:
  /// **'添加成员'**
  String get addMember;

  /// No description provided for @removeMember.
  ///
  /// In zh, this message translates to:
  /// **'移除成员'**
  String get removeMember;

  /// No description provided for @tags.
  ///
  /// In zh, this message translates to:
  /// **'标签'**
  String get tags;

  /// No description provided for @createTag.
  ///
  /// In zh, this message translates to:
  /// **'创建标签'**
  String get createTag;

  /// No description provided for @editTag.
  ///
  /// In zh, this message translates to:
  /// **'编辑标签'**
  String get editTag;

  /// No description provided for @deleteTag.
  ///
  /// In zh, this message translates to:
  /// **'删除标签'**
  String get deleteTag;

  /// No description provided for @tagName.
  ///
  /// In zh, this message translates to:
  /// **'标签名称'**
  String get tagName;

  /// No description provided for @color.
  ///
  /// In zh, this message translates to:
  /// **'颜色'**
  String get color;

  /// No description provided for @quickReplies.
  ///
  /// In zh, this message translates to:
  /// **'快捷回复'**
  String get quickReplies;

  /// No description provided for @createQuickReply.
  ///
  /// In zh, this message translates to:
  /// **'创建快捷回复'**
  String get createQuickReply;

  /// No description provided for @editQuickReply.
  ///
  /// In zh, this message translates to:
  /// **'编辑快捷回复'**
  String get editQuickReply;

  /// No description provided for @deleteQuickReply.
  ///
  /// In zh, this message translates to:
  /// **'删除快捷回复'**
  String get deleteQuickReply;

  /// No description provided for @label.
  ///
  /// In zh, this message translates to:
  /// **'标签'**
  String get label;

  /// No description provided for @message.
  ///
  /// In zh, this message translates to:
  /// **'消息'**
  String get message;

  /// No description provided for @autoSend.
  ///
  /// In zh, this message translates to:
  /// **'自动发送'**
  String get autoSend;

  /// No description provided for @regex.
  ///
  /// In zh, this message translates to:
  /// **'正则表达式'**
  String get regex;

  /// No description provided for @createRegex.
  ///
  /// In zh, this message translates to:
  /// **'创建正则'**
  String get createRegex;

  /// No description provided for @editRegex.
  ///
  /// In zh, this message translates to:
  /// **'编辑正则'**
  String get editRegex;

  /// No description provided for @deleteRegex.
  ///
  /// In zh, this message translates to:
  /// **'删除正则'**
  String get deleteRegex;

  /// No description provided for @pattern.
  ///
  /// In zh, this message translates to:
  /// **'模式'**
  String get pattern;

  /// No description provided for @replacement.
  ///
  /// In zh, this message translates to:
  /// **'替换'**
  String get replacement;

  /// No description provided for @backup.
  ///
  /// In zh, this message translates to:
  /// **'备份'**
  String get backup;

  /// No description provided for @backupSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'本地和云端备份与恢复'**
  String get backupSubtitle;

  /// No description provided for @createBackup.
  ///
  /// In zh, this message translates to:
  /// **'创建备份'**
  String get createBackup;

  /// No description provided for @restoreBackup.
  ///
  /// In zh, this message translates to:
  /// **'恢复备份'**
  String get restoreBackup;

  /// No description provided for @backupCreated.
  ///
  /// In zh, this message translates to:
  /// **'备份创建成功'**
  String get backupCreated;

  /// No description provided for @backupRestored.
  ///
  /// In zh, this message translates to:
  /// **'备份恢复成功'**
  String get backupRestored;

  /// No description provided for @backupFailed.
  ///
  /// In zh, this message translates to:
  /// **'备份失败：{error}'**
  String backupFailed(Object error);

  /// No description provided for @restoreFailed.
  ///
  /// In zh, this message translates to:
  /// **'恢复失败：{error}'**
  String restoreFailed(Object error);

  /// No description provided for @theme.
  ///
  /// In zh, this message translates to:
  /// **'主题'**
  String get theme;

  /// No description provided for @darkMode.
  ///
  /// In zh, this message translates to:
  /// **'深色模式'**
  String get darkMode;

  /// No description provided for @lightMode.
  ///
  /// In zh, this message translates to:
  /// **'浅色模式'**
  String get lightMode;

  /// No description provided for @systemTheme.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get systemTheme;

  /// No description provided for @primaryColor.
  ///
  /// In zh, this message translates to:
  /// **'主色调'**
  String get primaryColor;

  /// No description provided for @accentColor.
  ///
  /// In zh, this message translates to:
  /// **'强调色'**
  String get accentColor;

  /// No description provided for @advanced.
  ///
  /// In zh, this message translates to:
  /// **'高级'**
  String get advanced;

  /// No description provided for @advancedSettings.
  ///
  /// In zh, this message translates to:
  /// **'高级设置'**
  String get advancedSettings;

  /// No description provided for @statistics.
  ///
  /// In zh, this message translates to:
  /// **'统计'**
  String get statistics;

  /// No description provided for @totalChats.
  ///
  /// In zh, this message translates to:
  /// **'总聊天数'**
  String get totalChats;

  /// No description provided for @totalMessages.
  ///
  /// In zh, this message translates to:
  /// **'总消息数'**
  String get totalMessages;

  /// No description provided for @totalCharacters.
  ///
  /// In zh, this message translates to:
  /// **'总角色数'**
  String get totalCharacters;

  /// No description provided for @tokenizer.
  ///
  /// In zh, this message translates to:
  /// **'分词器'**
  String get tokenizer;

  /// No description provided for @tts.
  ///
  /// In zh, this message translates to:
  /// **'文字转语音'**
  String get tts;

  /// No description provided for @stt.
  ///
  /// In zh, this message translates to:
  /// **'语音转文字'**
  String get stt;

  /// No description provided for @translation.
  ///
  /// In zh, this message translates to:
  /// **'翻译'**
  String get translation;

  /// No description provided for @imageGeneration.
  ///
  /// In zh, this message translates to:
  /// **'图像生成'**
  String get imageGeneration;

  /// No description provided for @vectorStorage.
  ///
  /// In zh, this message translates to:
  /// **'向量存储'**
  String get vectorStorage;

  /// No description provided for @sprites.
  ///
  /// In zh, this message translates to:
  /// **'精灵图'**
  String get sprites;

  /// No description provided for @backgrounds.
  ///
  /// In zh, this message translates to:
  /// **'背景'**
  String get backgrounds;

  /// No description provided for @cfgScale.
  ///
  /// In zh, this message translates to:
  /// **'CFG比例'**
  String get cfgScale;

  /// No description provided for @logitBias.
  ///
  /// In zh, this message translates to:
  /// **'Logit偏置'**
  String get logitBias;

  /// No description provided for @variables.
  ///
  /// In zh, this message translates to:
  /// **'变量'**
  String get variables;

  /// No description provided for @listView.
  ///
  /// In zh, this message translates to:
  /// **'列表视图'**
  String get listView;

  /// No description provided for @gridView.
  ///
  /// In zh, this message translates to:
  /// **'网格视图'**
  String get gridView;

  /// No description provided for @search.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get search;

  /// No description provided for @searchCharacters.
  ///
  /// In zh, this message translates to:
  /// **'搜索角色...'**
  String get searchCharacters;

  /// No description provided for @noCharactersFound.
  ///
  /// In zh, this message translates to:
  /// **'未找到角色'**
  String get noCharactersFound;

  /// No description provided for @noCharactersYet.
  ///
  /// In zh, this message translates to:
  /// **'暂无角色'**
  String get noCharactersYet;

  /// No description provided for @importCharacter.
  ///
  /// In zh, this message translates to:
  /// **'导入角色以开始'**
  String get importCharacter;

  /// No description provided for @createCharacter.
  ///
  /// In zh, this message translates to:
  /// **'创建角色'**
  String get createCharacter;

  /// No description provided for @editCharacter.
  ///
  /// In zh, this message translates to:
  /// **'编辑角色'**
  String get editCharacter;

  /// No description provided for @deleteCharacter.
  ///
  /// In zh, this message translates to:
  /// **'删除角色'**
  String get deleteCharacter;

  /// No description provided for @deleteCharacterConfirmation.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除\"{name}\"吗？这也将删除与此角色的所有聊天。'**
  String deleteCharacterConfirmation(Object name);

  /// No description provided for @characterDeleted.
  ///
  /// In zh, this message translates to:
  /// **'角色已删除'**
  String get characterDeleted;

  /// No description provided for @startChat.
  ///
  /// In zh, this message translates to:
  /// **'开始聊天'**
  String get startChat;

  /// No description provided for @personality.
  ///
  /// In zh, this message translates to:
  /// **'性格'**
  String get personality;

  /// No description provided for @scenario.
  ///
  /// In zh, this message translates to:
  /// **'场景'**
  String get scenario;

  /// No description provided for @firstMessage.
  ///
  /// In zh, this message translates to:
  /// **'开场白'**
  String get firstMessage;

  /// No description provided for @exampleDialogue.
  ///
  /// In zh, this message translates to:
  /// **'示例对话'**
  String get exampleDialogue;

  /// No description provided for @creatorNotes.
  ///
  /// In zh, this message translates to:
  /// **'创作者注释'**
  String get creatorNotes;

  /// No description provided for @alternateGreetings.
  ///
  /// In zh, this message translates to:
  /// **'备选问候语'**
  String get alternateGreetings;

  /// No description provided for @characterBook.
  ///
  /// In zh, this message translates to:
  /// **'角色书'**
  String get characterBook;

  /// No description provided for @language.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get language;

  /// No description provided for @selectLanguage.
  ///
  /// In zh, this message translates to:
  /// **'选择语言'**
  String get selectLanguage;

  /// No description provided for @languageChanged.
  ///
  /// In zh, this message translates to:
  /// **'语言已更改'**
  String get languageChanged;

  /// No description provided for @about.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get about;

  /// No description provided for @version.
  ///
  /// In zh, this message translates to:
  /// **'版本'**
  String get version;

  /// No description provided for @licenses.
  ///
  /// In zh, this message translates to:
  /// **'许可证'**
  String get licenses;

  /// No description provided for @privacyPolicy.
  ///
  /// In zh, this message translates to:
  /// **'隐私政策'**
  String get privacyPolicy;

  /// No description provided for @termsOfService.
  ///
  /// In zh, this message translates to:
  /// **'服务条款'**
  String get termsOfService;

  /// No description provided for @feedback.
  ///
  /// In zh, this message translates to:
  /// **'反馈'**
  String get feedback;

  /// No description provided for @rateApp.
  ///
  /// In zh, this message translates to:
  /// **'评价应用'**
  String get rateApp;

  /// No description provided for @shareApp.
  ///
  /// In zh, this message translates to:
  /// **'分享应用'**
  String get shareApp;

  /// No description provided for @checkForUpdates.
  ///
  /// In zh, this message translates to:
  /// **'检查更新'**
  String get checkForUpdates;

  /// No description provided for @noUpdatesAvailable.
  ///
  /// In zh, this message translates to:
  /// **'没有可用更新'**
  String get noUpdatesAvailable;

  /// No description provided for @updateAvailable.
  ///
  /// In zh, this message translates to:
  /// **'有可用更新'**
  String get updateAvailable;

  /// No description provided for @downloadUpdate.
  ///
  /// In zh, this message translates to:
  /// **'下载更新'**
  String get downloadUpdate;

  /// No description provided for @bookmarkCreated.
  ///
  /// In zh, this message translates to:
  /// **'书签已创建'**
  String get bookmarkCreated;

  /// No description provided for @bookmarkName.
  ///
  /// In zh, this message translates to:
  /// **'书签名称'**
  String get bookmarkName;

  /// No description provided for @enterBookmarkName.
  ///
  /// In zh, this message translates to:
  /// **'输入书签名称'**
  String get enterBookmarkName;

  /// No description provided for @noBookmarksYet.
  ///
  /// In zh, this message translates to:
  /// **'暂无书签'**
  String get noBookmarksYet;

  /// No description provided for @createBookmarkDescription.
  ///
  /// In zh, this message translates to:
  /// **'创建书签以保存对话中的重要节点'**
  String get createBookmarkDescription;

  /// No description provided for @jumpToBookmark.
  ///
  /// In zh, this message translates to:
  /// **'跳转到书签'**
  String get jumpToBookmark;

  /// No description provided for @deleteBookmark.
  ///
  /// In zh, this message translates to:
  /// **'删除书签'**
  String get deleteBookmark;

  /// No description provided for @bookmarkDeleted.
  ///
  /// In zh, this message translates to:
  /// **'书签已删除'**
  String get bookmarkDeleted;

  /// No description provided for @saveAsJsonl.
  ///
  /// In zh, this message translates to:
  /// **'保存为JSONL'**
  String get saveAsJsonl;

  /// No description provided for @saveAsJson.
  ///
  /// In zh, this message translates to:
  /// **'保存为JSON'**
  String get saveAsJson;

  /// No description provided for @keyboardShortcuts.
  ///
  /// In zh, this message translates to:
  /// **'键盘快捷键：'**
  String get keyboardShortcuts;

  /// No description provided for @bold.
  ///
  /// In zh, this message translates to:
  /// **'粗体'**
  String get bold;

  /// No description provided for @italic.
  ///
  /// In zh, this message translates to:
  /// **'斜体'**
  String get italic;

  /// No description provided for @underline.
  ///
  /// In zh, this message translates to:
  /// **'下划线'**
  String get underline;

  /// No description provided for @strikethrough.
  ///
  /// In zh, this message translates to:
  /// **'删除线'**
  String get strikethrough;

  /// No description provided for @inlineCode.
  ///
  /// In zh, this message translates to:
  /// **'行内代码'**
  String get inlineCode;

  /// No description provided for @link.
  ///
  /// In zh, this message translates to:
  /// **'链接'**
  String get link;

  /// No description provided for @slashCommands.
  ///
  /// In zh, this message translates to:
  /// **'斜杠命令'**
  String get slashCommands;

  /// No description provided for @availableCommands.
  ///
  /// In zh, this message translates to:
  /// **'可用命令：'**
  String get availableCommands;

  /// No description provided for @commandHelp.
  ///
  /// In zh, this message translates to:
  /// **'输入 / 查看可用命令'**
  String get commandHelp;

  /// No description provided for @debugLog.
  ///
  /// In zh, this message translates to:
  /// **'调试日志'**
  String get debugLog;

  /// No description provided for @debugLogDescription.
  ///
  /// In zh, this message translates to:
  /// **'显示悬浮调试按钮以查看日志'**
  String get debugLogDescription;

  /// No description provided for @autoScroll.
  ///
  /// In zh, this message translates to:
  /// **'自动滚动'**
  String get autoScroll;

  /// No description provided for @clearLogs.
  ///
  /// In zh, this message translates to:
  /// **'清除日志'**
  String get clearLogs;

  /// No description provided for @searchLogs.
  ///
  /// In zh, this message translates to:
  /// **'搜索日志...'**
  String get searchLogs;

  /// No description provided for @noLogsYet.
  ///
  /// In zh, this message translates to:
  /// **'暂无日志'**
  String get noLogsYet;

  /// No description provided for @contextManagement.
  ///
  /// In zh, this message translates to:
  /// **'上下文管理'**
  String get contextManagement;

  /// No description provided for @autoSummarize.
  ///
  /// In zh, this message translates to:
  /// **'自动总结'**
  String get autoSummarize;

  /// No description provided for @autoSummarizeDescription.
  ///
  /// In zh, this message translates to:
  /// **'当上下文使用率较高时自动总结并压缩聊天历史'**
  String get autoSummarizeDescription;

  /// No description provided for @autoSummarizeThreshold.
  ///
  /// In zh, this message translates to:
  /// **'自动总结阈值'**
  String get autoSummarizeThreshold;

  /// No description provided for @autoSummarizeThresholdDescription.
  ///
  /// In zh, this message translates to:
  /// **'当上下文达到最大值的此百分比时触发总结'**
  String get autoSummarizeThresholdDescription;

  /// No description provided for @allCharactersAvailable.
  ///
  /// In zh, this message translates to:
  /// **'所有角色'**
  String get allCharactersAvailable;

  /// No description provided for @availableToAllCharactersNotGlobal.
  ///
  /// In zh, this message translates to:
  /// **'所有角色可用（上下文匹配）'**
  String get availableToAllCharactersNotGlobal;

  /// No description provided for @specificCharacter.
  ///
  /// In zh, this message translates to:
  /// **'特定角色'**
  String get specificCharacter;

  /// No description provided for @linkToSpecificCharacter.
  ///
  /// In zh, this message translates to:
  /// **'仅关联到特定角色'**
  String get linkToSpecificCharacter;

  /// No description provided for @selectCharacter.
  ///
  /// In zh, this message translates to:
  /// **'选择角色'**
  String get selectCharacter;

  /// No description provided for @noCharactersAvailable.
  ///
  /// In zh, this message translates to:
  /// **'暂无可用角色'**
  String get noCharactersAvailable;

  /// No description provided for @pleaseSelectCharacter.
  ///
  /// In zh, this message translates to:
  /// **'请选择一个角色'**
  String get pleaseSelectCharacter;

  /// No description provided for @contextUsage.
  ///
  /// In zh, this message translates to:
  /// **'上下文使用'**
  String get contextUsage;

  /// No description provided for @totalTokens.
  ///
  /// In zh, this message translates to:
  /// **'总令牌数'**
  String get totalTokens;

  /// No description provided for @maxContext.
  ///
  /// In zh, this message translates to:
  /// **'最大上下文'**
  String get maxContext;

  /// No description provided for @remaining.
  ///
  /// In zh, this message translates to:
  /// **'剩余'**
  String get remaining;

  /// No description provided for @breakdown.
  ///
  /// In zh, this message translates to:
  /// **'详细分解'**
  String get breakdown;

  /// No description provided for @cloudBackup.
  ///
  /// In zh, this message translates to:
  /// **'云备份'**
  String get cloudBackup;

  /// No description provided for @cloudBackupInfo.
  ///
  /// In zh, this message translates to:
  /// **'云备份'**
  String get cloudBackupInfo;

  /// No description provided for @cloudBackupDescription.
  ///
  /// In zh, this message translates to:
  /// **'跨设备同步数据'**
  String get cloudBackupDescription;

  /// No description provided for @cloudBackupSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'备份到 iCloud 或 Google Drive，在任何设备上恢复'**
  String get cloudBackupSubtitle;

  /// No description provided for @enableICloudBackup.
  ///
  /// In zh, this message translates to:
  /// **'启用 iCloud 备份'**
  String get enableICloudBackup;

  /// No description provided for @enableICloudBackupDescription.
  ///
  /// In zh, this message translates to:
  /// **'自动同步备份到 iCloud'**
  String get enableICloudBackupDescription;

  /// No description provided for @iCloudNotAvailable.
  ///
  /// In zh, this message translates to:
  /// **'iCloud 不可用'**
  String get iCloudNotAvailable;

  /// No description provided for @iCloudNotAvailableDescription.
  ///
  /// In zh, this message translates to:
  /// **'请在设置中登录 iCloud'**
  String get iCloudNotAvailableDescription;

  /// No description provided for @backupToICloud.
  ///
  /// In zh, this message translates to:
  /// **'备份到 iCloud'**
  String get backupToICloud;

  /// No description provided for @lastSync.
  ///
  /// In zh, this message translates to:
  /// **'上次同步：{time}'**
  String lastSync(Object time);

  /// No description provided for @neverSynced.
  ///
  /// In zh, this message translates to:
  /// **'从未同步'**
  String get neverSynced;

  /// No description provided for @iCloudBackups.
  ///
  /// In zh, this message translates to:
  /// **'iCloud 备份'**
  String get iCloudBackups;

  /// No description provided for @noCloudBackups.
  ///
  /// In zh, this message translates to:
  /// **'暂无云备份'**
  String get noCloudBackups;

  /// No description provided for @googleDriveExport.
  ///
  /// In zh, this message translates to:
  /// **'导出到 Google Drive'**
  String get googleDriveExport;

  /// No description provided for @googleDriveExportDescription.
  ///
  /// In zh, this message translates to:
  /// **'保存备份文件到 Google Drive 或其他位置'**
  String get googleDriveExportDescription;

  /// No description provided for @googleDriveImport.
  ///
  /// In zh, this message translates to:
  /// **'从 Google Drive 导入'**
  String get googleDriveImport;

  /// No description provided for @googleDriveImportDescription.
  ///
  /// In zh, this message translates to:
  /// **'从 Google Drive 或其他位置恢复备份文件'**
  String get googleDriveImportDescription;

  /// No description provided for @export.
  ///
  /// In zh, this message translates to:
  /// **'导出'**
  String get export;

  /// No description provided for @import_action.
  ///
  /// In zh, this message translates to:
  /// **'导入'**
  String get import_action;

  /// No description provided for @importBackup.
  ///
  /// In zh, this message translates to:
  /// **'导入备份'**
  String get importBackup;

  /// No description provided for @backupExported.
  ///
  /// In zh, this message translates to:
  /// **'备份导出成功'**
  String get backupExported;

  /// No description provided for @restoreSettings.
  ///
  /// In zh, this message translates to:
  /// **'恢复设置'**
  String get restoreSettings;

  /// No description provided for @defaultRestoreMode.
  ///
  /// In zh, this message translates to:
  /// **'默认恢复模式'**
  String get defaultRestoreMode;

  /// No description provided for @selectRestoreMode.
  ///
  /// In zh, this message translates to:
  /// **'选择数据恢复方式：'**
  String get selectRestoreMode;

  /// No description provided for @restoreWarning.
  ///
  /// In zh, this message translates to:
  /// **'根据所选模式，恢复数据可能会覆盖现有数据。请确保先备份当前数据。'**
  String get restoreWarning;

  /// No description provided for @restore.
  ///
  /// In zh, this message translates to:
  /// **'恢复'**
  String get restore;

  /// No description provided for @restoreComplete.
  ///
  /// In zh, this message translates to:
  /// **'恢复完成：新增 {added} 项，更新 {updated} 项，跳过 {skipped} 项'**
  String restoreComplete(Object added, Object skipped, Object updated);

  /// No description provided for @selectFileAndImport.
  ///
  /// In zh, this message translates to:
  /// **'选择文件并导入'**
  String get selectFileAndImport;

  /// No description provided for @aboutRestoreModes.
  ///
  /// In zh, this message translates to:
  /// **'关于恢复模式'**
  String get aboutRestoreModes;

  /// No description provided for @aboutRestoreModesDescription.
  ///
  /// In zh, this message translates to:
  /// **'替换：用备份数据覆盖所有本地数据。\\n合并：保留两者，冲突时新数据优先。\\n仅添加新项：仅从备份添加新项，保留所有现有数据。'**
  String get aboutRestoreModesDescription;

  /// No description provided for @backupAndRestore.
  ///
  /// In zh, this message translates to:
  /// **'备份与恢复'**
  String get backupAndRestore;

  /// No description provided for @refresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新'**
  String get refresh;

  /// No description provided for @storage.
  ///
  /// In zh, this message translates to:
  /// **'存储'**
  String get storage;

  /// No description provided for @totalBackupSize.
  ///
  /// In zh, this message translates to:
  /// **'备份总大小'**
  String get totalBackupSize;

  /// No description provided for @calculating.
  ///
  /// In zh, this message translates to:
  /// **'计算中...'**
  String get calculating;

  /// No description provided for @lastAutoBackup.
  ///
  /// In zh, this message translates to:
  /// **'上次自动备份'**
  String get lastAutoBackup;

  /// No description provided for @autoBackup.
  ///
  /// In zh, this message translates to:
  /// **'自动备份'**
  String get autoBackup;

  /// No description provided for @enableAutoBackup.
  ///
  /// In zh, this message translates to:
  /// **'启用自动备份'**
  String get enableAutoBackup;

  /// No description provided for @automaticallyBackupChats.
  ///
  /// In zh, this message translates to:
  /// **'自动备份聊天记录'**
  String get automaticallyBackupChats;

  /// No description provided for @backupInterval.
  ///
  /// In zh, this message translates to:
  /// **'备份间隔'**
  String get backupInterval;

  /// No description provided for @backupOnExit.
  ///
  /// In zh, this message translates to:
  /// **'退出时备份'**
  String get backupOnExit;

  /// No description provided for @createBackupWhenClosingApp.
  ///
  /// In zh, this message translates to:
  /// **'关闭应用时创建备份'**
  String get createBackupWhenClosingApp;

  /// No description provided for @retention.
  ///
  /// In zh, this message translates to:
  /// **'保留策略'**
  String get retention;

  /// No description provided for @maxChatBackups.
  ///
  /// In zh, this message translates to:
  /// **'最大聊天备份数'**
  String get maxChatBackups;

  /// No description provided for @keepUpToChatBackups.
  ///
  /// In zh, this message translates to:
  /// **'最多保留 {count} 个聊天备份'**
  String keepUpToChatBackups(Object count);

  /// No description provided for @maxFullBackups.
  ///
  /// In zh, this message translates to:
  /// **'最大完整备份数'**
  String get maxFullBackups;

  /// No description provided for @keepUpToFullBackups.
  ///
  /// In zh, this message translates to:
  /// **'最多保留 {count} 个完整备份'**
  String keepUpToFullBackups(Object count);

  /// No description provided for @cleanupOldBackups.
  ///
  /// In zh, this message translates to:
  /// **'清理旧备份'**
  String get cleanupOldBackups;

  /// No description provided for @deleteBackupsExceedingLimits.
  ///
  /// In zh, this message translates to:
  /// **'删除超过限制的备份'**
  String get deleteBackupsExceedingLimits;

  /// No description provided for @cleanup.
  ///
  /// In zh, this message translates to:
  /// **'清理'**
  String get cleanup;

  /// No description provided for @deletedOldBackups.
  ///
  /// In zh, this message translates to:
  /// **'已删除 {count} 个旧备份'**
  String deletedOldBackups(Object count);

  /// No description provided for @chatBackups.
  ///
  /// In zh, this message translates to:
  /// **'聊天备份'**
  String get chatBackups;

  /// No description provided for @noChatBackups.
  ///
  /// In zh, this message translates to:
  /// **'暂无聊天备份'**
  String get noChatBackups;

  /// No description provided for @viewAllBackups.
  ///
  /// In zh, this message translates to:
  /// **'查看全部 {count} 个备份'**
  String viewAllBackups(Object count);

  /// No description provided for @fullBackups.
  ///
  /// In zh, this message translates to:
  /// **'完整备份'**
  String get fullBackups;

  /// No description provided for @noFullBackups.
  ///
  /// In zh, this message translates to:
  /// **'暂无完整备份'**
  String get noFullBackups;

  /// No description provided for @information.
  ///
  /// In zh, this message translates to:
  /// **'信息'**
  String get information;

  /// No description provided for @aboutBackups.
  ///
  /// In zh, this message translates to:
  /// **'关于备份'**
  String get aboutBackups;

  /// No description provided for @aboutBackupsDescription.
  ///
  /// In zh, this message translates to:
  /// **'聊天备份保存单个对话。完整备份包含所有角色、聊天、设置和世界信息。'**
  String get aboutBackupsDescription;

  /// No description provided for @backupLocation.
  ///
  /// In zh, this message translates to:
  /// **'备份位置'**
  String get backupLocation;

  /// No description provided for @errorReadingBackup.
  ///
  /// In zh, this message translates to:
  /// **'读取备份错误：{error}'**
  String errorReadingBackup(Object error);

  /// No description provided for @deleteBackup.
  ///
  /// In zh, this message translates to:
  /// **'删除备份'**
  String get deleteBackup;

  /// No description provided for @deleteBackupConfirmation.
  ///
  /// In zh, this message translates to:
  /// **'删除 \"{name}\"？\\n\\n此操作无法撤销。'**
  String deleteBackupConfirmation(Object name);

  /// No description provided for @view.
  ///
  /// In zh, this message translates to:
  /// **'查看'**
  String get view;

  /// No description provided for @justNow.
  ///
  /// In zh, this message translates to:
  /// **'刚刚'**
  String get justNow;

  /// No description provided for @minutesAgo.
  ///
  /// In zh, this message translates to:
  /// **'{count} 分钟前'**
  String minutesAgo(Object count);

  /// No description provided for @hoursAgo.
  ///
  /// In zh, this message translates to:
  /// **'{count} 小时前'**
  String hoursAgo(Object count);

  /// No description provided for @processing.
  ///
  /// In zh, this message translates to:
  /// **'处理中...'**
  String get processing;

  /// No description provided for @signInToGoogleDrive.
  ///
  /// In zh, this message translates to:
  /// **'登录 Google Drive'**
  String get signInToGoogleDrive;

  /// No description provided for @signInToGoogleDriveDescription.
  ///
  /// In zh, this message translates to:
  /// **'使用 Google 账户登录以备份和恢复数据'**
  String get signInToGoogleDriveDescription;

  /// No description provided for @signIn.
  ///
  /// In zh, this message translates to:
  /// **'登录'**
  String get signIn;

  /// No description provided for @signOut.
  ///
  /// In zh, this message translates to:
  /// **'退出登录'**
  String get signOut;

  /// No description provided for @signedInSuccessfully.
  ///
  /// In zh, this message translates to:
  /// **'登录成功'**
  String get signedInSuccessfully;

  /// No description provided for @backupToGoogleDrive.
  ///
  /// In zh, this message translates to:
  /// **'备份到 Google Drive'**
  String get backupToGoogleDrive;

  /// No description provided for @googleDriveBackups.
  ///
  /// In zh, this message translates to:
  /// **'Google Drive 备份'**
  String get googleDriveBackups;

  /// No description provided for @saveAs.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get saveAs;

  /// No description provided for @contextLength.
  ///
  /// In zh, this message translates to:
  /// **'文本'**
  String get contextLength;

  /// No description provided for @contextWindowSize.
  ///
  /// In zh, this message translates to:
  /// **'文本'**
  String get contextWindowSize;

  /// No description provided for @contextLengthDescription.
  ///
  /// In zh, this message translates to:
  /// **'模型'**
  String get contextLengthDescription;

  /// No description provided for @characterNotFound.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get characterNotFound;

  /// No description provided for @characterNotFoundMessage.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get characterNotFoundMessage;

  /// No description provided for @exportAsPng.
  ///
  /// In zh, this message translates to:
  /// **'导出为PNG图片卡'**
  String get exportAsPng;

  /// No description provided for @exportAsCharx.
  ///
  /// In zh, this message translates to:
  /// **'导出为CharX'**
  String get exportAsCharx;

  /// No description provided for @exportAsJson.
  ///
  /// In zh, this message translates to:
  /// **'导出为JSON'**
  String get exportAsJson;

  /// No description provided for @duplicate.
  ///
  /// In zh, this message translates to:
  /// **'复制角色'**
  String get duplicate;

  /// No description provided for @deleteCharacterConfirmationSimple.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String deleteCharacterConfirmationSimple(Object name);

  /// No description provided for @characterDuplicated.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String characterDuplicated(Object name);

  /// No description provided for @failedToDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String failedToDelete(Object error);

  /// No description provided for @failedToDuplicate.
  ///
  /// In zh, this message translates to:
  /// **'错误'**
  String failedToDuplicate(Object error);

  /// No description provided for @pngExportComingSoon.
  ///
  /// In zh, this message translates to:
  /// **'导出'**
  String get pngExportComingSoon;

  /// No description provided for @charxExportComingSoon.
  ///
  /// In zh, this message translates to:
  /// **'导出'**
  String get charxExportComingSoon;

  /// No description provided for @failedToCreateChat.
  ///
  /// In zh, this message translates to:
  /// **'聊天'**
  String get failedToCreateChat;

  /// No description provided for @creating.
  ///
  /// In zh, this message translates to:
  /// **'创建中...'**
  String get creating;

  /// No description provided for @byCreator.
  ///
  /// In zh, this message translates to:
  /// **'由 {creator} 创建'**
  String byCreator(Object creator);

  /// No description provided for @versionLabel.
  ///
  /// In zh, this message translates to:
  /// **'v{version}'**
  String versionLabel(Object version);

  /// No description provided for @showLess.
  ///
  /// In zh, this message translates to:
  /// **'显示'**
  String get showLess;

  /// No description provided for @showMore.
  ///
  /// In zh, this message translates to:
  /// **'显示'**
  String get showMore;

  /// No description provided for @greetingNumber.
  ///
  /// In zh, this message translates to:
  /// **'数字'**
  String greetingNumber(Object number);

  /// No description provided for @alternateGreetingsCount.
  ///
  /// In zh, this message translates to:
  /// **'计数'**
  String alternateGreetingsCount(Object count);

  /// No description provided for @embeddedLorebook.
  ///
  /// In zh, this message translates to:
  /// **'内嵌世界书'**
  String get embeddedLorebook;

  /// No description provided for @entriesEnabled.
  ///
  /// In zh, this message translates to:
  /// **'启用'**
  String entriesEnabled(Object enabled, Object total);

  /// No description provided for @andMoreEntries.
  ///
  /// In zh, this message translates to:
  /// **'计数'**
  String andMoreEntries(Object count);

  /// No description provided for @exampleMessages.
  ///
  /// In zh, this message translates to:
  /// **'消息'**
  String get exampleMessages;

  /// No description provided for @postHistoryInstructions.
  ///
  /// In zh, this message translates to:
  /// **'历史后指令'**
  String get postHistoryInstructions;

  /// No description provided for @selectImages.
  ///
  /// In zh, this message translates to:
  /// **'图像'**
  String get selectImages;

  /// No description provided for @presetsAndTemplates.
  ///
  /// In zh, this message translates to:
  /// **'预设'**
  String get presetsAndTemplates;

  /// No description provided for @activePreset.
  ///
  /// In zh, this message translates to:
  /// **'预设'**
  String get activePreset;

  /// No description provided for @change.
  ///
  /// In zh, this message translates to:
  /// **'更改'**
  String get change;

  /// No description provided for @noPresetSelected.
  ///
  /// In zh, this message translates to:
  /// **'预设'**
  String get noPresetSelected;

  /// No description provided for @instructTemplate.
  ///
  /// In zh, this message translates to:
  /// **'指令模板'**
  String get instructTemplate;

  /// No description provided for @selectInstructTemplate.
  ///
  /// In zh, this message translates to:
  /// **'选择'**
  String get selectInstructTemplate;

  /// No description provided for @instructTemplateDescription.
  ///
  /// In zh, this message translates to:
  /// **'模型'**
  String get instructTemplateDescription;

  /// No description provided for @orderAndTogglePromptSections.
  ///
  /// In zh, this message translates to:
  /// **'提示'**
  String get orderAndTogglePromptSections;

  /// No description provided for @llmConnection.
  ///
  /// In zh, this message translates to:
  /// **'LLM 连接'**
  String get llmConnection;

  /// No description provided for @generationSettings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get generationSettings;

  /// No description provided for @advancedSamplerSettings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get advancedSamplerSettings;

  /// No description provided for @fullControlOverSampling.
  ///
  /// In zh, this message translates to:
  /// **'完全控制采样参数'**
  String get fullControlOverSampling;

  /// No description provided for @selectLlmProvider.
  ///
  /// In zh, this message translates to:
  /// **'选择'**
  String get selectLlmProvider;

  /// No description provided for @notSet.
  ///
  /// In zh, this message translates to:
  /// **'未设置'**
  String get notSet;

  /// No description provided for @enterApiKey.
  ///
  /// In zh, this message translates to:
  /// **'输入你的 API 密钥'**
  String get enterApiKey;

  /// No description provided for @apiEndpointUrl.
  ///
  /// In zh, this message translates to:
  /// **'API 端点地址'**
  String get apiEndpointUrl;

  /// No description provided for @modelName.
  ///
  /// In zh, this message translates to:
  /// **'模型'**
  String get modelName;

  /// No description provided for @fetchAvailableModels.
  ///
  /// In zh, this message translates to:
  /// **'模型'**
  String get fetchAvailableModels;

  /// No description provided for @fetchModelsDescription.
  ///
  /// In zh, this message translates to:
  /// **'模型'**
  String get fetchModelsDescription;

  /// No description provided for @enterModelName.
  ///
  /// In zh, this message translates to:
  /// **'模型'**
  String get enterModelName;

  /// No description provided for @fetchingModels.
  ///
  /// In zh, this message translates to:
  /// **'模型'**
  String get fetchingModels;

  /// No description provided for @failedToFetchModels.
  ///
  /// In zh, this message translates to:
  /// **'模型'**
  String get failedToFetchModels;

  /// No description provided for @tapToTestConnection.
  ///
  /// In zh, this message translates to:
  /// **'测试'**
  String get tapToTestConnection;

  /// No description provided for @testing.
  ///
  /// In zh, this message translates to:
  /// **'测试'**
  String get testing;

  /// No description provided for @connected.
  ///
  /// In zh, this message translates to:
  /// **'已连接'**
  String get connected;

  /// No description provided for @connectionFailedSimple.
  ///
  /// In zh, this message translates to:
  /// **'失败'**
  String get connectionFailedSimple;

  /// No description provided for @maximumTokensToGenerate.
  ///
  /// In zh, this message translates to:
  /// **'令牌'**
  String get maximumTokensToGenerate;

  /// No description provided for @streaming.
  ///
  /// In zh, this message translates to:
  /// **'流式输出'**
  String get streaming;

  /// No description provided for @showResponseAsItGenerates.
  ///
  /// In zh, this message translates to:
  /// **'显示'**
  String get showResponseAsItGenerates;

  /// No description provided for @selectModelCount.
  ///
  /// In zh, this message translates to:
  /// **'模型'**
  String selectModelCount(Object count);

  /// No description provided for @refreshModels.
  ///
  /// In zh, this message translates to:
  /// **'模型'**
  String get refreshModels;

  /// No description provided for @enterManually.
  ///
  /// In zh, this message translates to:
  /// **'手动'**
  String get enterManually;

  /// No description provided for @noModelsFound.
  ///
  /// In zh, this message translates to:
  /// **'模型'**
  String get noModelsFound;

  /// No description provided for @tryDifferentSearchTerm.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get tryDifferentSearchTerm;

  /// No description provided for @modelsOfTotal.
  ///
  /// In zh, this message translates to:
  /// **'模型'**
  String modelsOfTotal(Object filtered, Object total);

  /// No description provided for @importPreset.
  ///
  /// In zh, this message translates to:
  /// **'预设'**
  String get importPreset;

  /// No description provided for @noGroupChatsYet.
  ///
  /// In zh, this message translates to:
  /// **'聊天'**
  String get noGroupChatsYet;

  /// No description provided for @createGroupDescription.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get createGroupDescription;

  /// No description provided for @newGroup.
  ///
  /// In zh, this message translates to:
  /// **'新建群组'**
  String get newGroup;

  /// No description provided for @membersAndMode.
  ///
  /// In zh, this message translates to:
  /// **'模式'**
  String membersAndMode(Object count, Object mode);

  /// No description provided for @groupChatWillBeImplemented.
  ///
  /// In zh, this message translates to:
  /// **'聊天'**
  String get groupChatWillBeImplemented;

  /// No description provided for @deleteGroupConfirmation.
  ///
  /// In zh, this message translates to:
  /// **'聊天'**
  String deleteGroupConfirmation(Object name);

  /// No description provided for @groupDeleted.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String groupDeleted(Object name);

  /// No description provided for @groupNameRequired.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get groupNameRequired;

  /// No description provided for @enterGroupName.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get enterGroupName;

  /// No description provided for @optionalDescription.
  ///
  /// In zh, this message translates to:
  /// **'描述'**
  String get optionalDescription;

  /// No description provided for @selectCharacters.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get selectCharacters;

  /// No description provided for @charactersSelected.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String charactersSelected(Object count);

  /// No description provided for @create.
  ///
  /// In zh, this message translates to:
  /// **'创建'**
  String get create;

  /// No description provided for @selectAtLeast2Characters.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get selectAtLeast2Characters;

  /// No description provided for @groupCreatedSuccessfully.
  ///
  /// In zh, this message translates to:
  /// **'成功'**
  String get groupCreatedSuccessfully;

  /// No description provided for @failedToCreateGroup.
  ///
  /// In zh, this message translates to:
  /// **'错误'**
  String failedToCreateGroup(Object error);

  /// No description provided for @selectCharacterCard.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get selectCharacterCard;

  /// No description provided for @supportsPngCharxJson.
  ///
  /// In zh, this message translates to:
  /// **'支持 PNG、CharX 和 JSON 格式'**
  String get supportsPngCharxJson;

  /// No description provided for @browseFiles.
  ///
  /// In zh, this message translates to:
  /// **'文件'**
  String get browseFiles;

  /// No description provided for @failedToPickFile.
  ///
  /// In zh, this message translates to:
  /// **'错误'**
  String failedToPickFile(Object error);

  /// No description provided for @failedToLoadCharacter.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String failedToLoadCharacter(Object error);

  /// No description provided for @unsupportedFileFormat.
  ///
  /// In zh, this message translates to:
  /// **'文件'**
  String unsupportedFileFormat(Object format);

  /// No description provided for @pngCharacterCard.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get pngCharacterCard;

  /// No description provided for @characterDataEmbeddedInImage.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get characterDataEmbeddedInImage;

  /// No description provided for @charxArchive.
  ///
  /// In zh, this message translates to:
  /// **'CharX 压缩包'**
  String get charxArchive;

  /// No description provided for @zipArchiveWithCharacterData.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get zipArchiveWithCharacterData;

  /// No description provided for @plainCharacterCardJson.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get plainCharacterCardJson;

  /// No description provided for @importedWithLorebook.
  ///
  /// In zh, this message translates to:
  /// **'导入'**
  String importedWithLorebook(Object name);

  /// No description provided for @importedSuccessfully.
  ///
  /// In zh, this message translates to:
  /// **'导入'**
  String importedSuccessfully(Object name);

  /// No description provided for @failedToImport.
  ///
  /// In zh, this message translates to:
  /// **'导入'**
  String failedToImport(Object error);

  /// No description provided for @embeddedLorebookEntries.
  ///
  /// In zh, this message translates to:
  /// **'计数'**
  String embeddedLorebookEntries(Object count);

  /// No description provided for @saveCurrentAsPreset.
  ///
  /// In zh, this message translates to:
  /// **'预设'**
  String get saveCurrentAsPreset;

  /// No description provided for @exportCurrentSettings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get exportCurrentSettings;

  /// No description provided for @builtInPresets.
  ///
  /// In zh, this message translates to:
  /// **'预设'**
  String get builtInPresets;

  /// No description provided for @customPresets.
  ///
  /// In zh, this message translates to:
  /// **'预设'**
  String get customPresets;

  /// No description provided for @aiPresetsDescription.
  ///
  /// In zh, this message translates to:
  /// **'预设'**
  String get aiPresetsDescription;

  /// No description provided for @appliedPreset.
  ///
  /// In zh, this message translates to:
  /// **'预设'**
  String appliedPreset(Object name);

  /// No description provided for @failedToApplyPreset.
  ///
  /// In zh, this message translates to:
  /// **'预设'**
  String failedToApplyPreset(Object error);

  /// No description provided for @invalidPresetFormat.
  ///
  /// In zh, this message translates to:
  /// **'预设'**
  String get invalidPresetFormat;

  /// No description provided for @importedAndApplied.
  ///
  /// In zh, this message translates to:
  /// **'导入'**
  String importedAndApplied(Object name);

  /// No description provided for @saveAsPreset.
  ///
  /// In zh, this message translates to:
  /// **'预设'**
  String get saveAsPreset;

  /// No description provided for @descriptionOptional.
  ///
  /// In zh, this message translates to:
  /// **'描述'**
  String get descriptionOptional;

  /// No description provided for @pleaseEnterAName.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get pleaseEnterAName;

  /// No description provided for @savedPreset.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String savedPreset(Object name);

  /// No description provided for @saveFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String saveFailed(Object error);

  /// No description provided for @deletePresetConfirmation.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String deletePresetConfirmation(Object name);

  /// No description provided for @deletedPreset.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String deletedPreset(Object name);

  /// No description provided for @resetToDefaults.
  ///
  /// In zh, this message translates to:
  /// **'重置'**
  String get resetToDefaults;

  /// No description provided for @basicSampling.
  ///
  /// In zh, this message translates to:
  /// **'基础采样'**
  String get basicSampling;

  /// No description provided for @temperatureDescription.
  ///
  /// In zh, this message translates to:
  /// **'控制随机性。越高越有创意，越低越专注。'**
  String get temperatureDescription;

  /// No description provided for @topPNucleusSampling.
  ///
  /// In zh, this message translates to:
  /// **'Top P (核采样)'**
  String get topPNucleusSampling;

  /// No description provided for @topPDescription.
  ///
  /// In zh, this message translates to:
  /// **'令牌'**
  String get topPDescription;

  /// No description provided for @topKDescription.
  ///
  /// In zh, this message translates to:
  /// **'令牌'**
  String get topKDescription;

  /// No description provided for @advancedSampling.
  ///
  /// In zh, this message translates to:
  /// **'高级'**
  String get advancedSampling;

  /// No description provided for @minP.
  ///
  /// In zh, this message translates to:
  /// **'最小'**
  String get minP;

  /// No description provided for @minPDescription.
  ///
  /// In zh, this message translates to:
  /// **'令牌'**
  String get minPDescription;

  /// No description provided for @typicalP.
  ///
  /// In zh, this message translates to:
  /// **'Typical P'**
  String get typicalP;

  /// No description provided for @typicalPDescription.
  ///
  /// In zh, this message translates to:
  /// **'禁用'**
  String get typicalPDescription;

  /// No description provided for @topA.
  ///
  /// In zh, this message translates to:
  /// **'顶部'**
  String get topA;

  /// No description provided for @topADescription.
  ///
  /// In zh, this message translates to:
  /// **'禁用'**
  String get topADescription;

  /// No description provided for @tailFreeSamplingTfs.
  ///
  /// In zh, this message translates to:
  /// **'无尾采样 (TFS)'**
  String get tailFreeSamplingTfs;

  /// No description provided for @tfsDescription.
  ///
  /// In zh, this message translates to:
  /// **'禁用'**
  String get tfsDescription;

  /// No description provided for @repetitionControl.
  ///
  /// In zh, this message translates to:
  /// **'重复控制'**
  String get repetitionControl;

  /// No description provided for @repetitionPenaltyDescription.
  ///
  /// In zh, this message translates to:
  /// **'令牌'**
  String get repetitionPenaltyDescription;

  /// No description provided for @repetitionPenaltyRange.
  ///
  /// In zh, this message translates to:
  /// **'重复惩罚范围'**
  String get repetitionPenaltyRange;

  /// No description provided for @repetitionPenaltyRangeDescription.
  ///
  /// In zh, this message translates to:
  /// **'令牌'**
  String get repetitionPenaltyRangeDescription;

  /// No description provided for @frequencyPenaltyDescription.
  ///
  /// In zh, this message translates to:
  /// **'令牌'**
  String get frequencyPenaltyDescription;

  /// No description provided for @presencePenaltyDescription.
  ///
  /// In zh, this message translates to:
  /// **'令牌'**
  String get presencePenaltyDescription;

  /// No description provided for @mirostatLocalModels.
  ///
  /// In zh, this message translates to:
  /// **'模型'**
  String get mirostatLocalModels;

  /// No description provided for @mirostatMode.
  ///
  /// In zh, this message translates to:
  /// **'模式'**
  String get mirostatMode;

  /// No description provided for @adaptiveSamplingForLocalModels.
  ///
  /// In zh, this message translates to:
  /// **'模型'**
  String get adaptiveSamplingForLocalModels;

  /// No description provided for @off.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get off;

  /// No description provided for @mirostatTau.
  ///
  /// In zh, this message translates to:
  /// **'Mirostat Tau'**
  String get mirostatTau;

  /// No description provided for @mirostatTauDescription.
  ///
  /// In zh, this message translates to:
  /// **'目标熵/困惑度。'**
  String get mirostatTauDescription;

  /// No description provided for @mirostatEta.
  ///
  /// In zh, this message translates to:
  /// **'Mirostat Eta'**
  String get mirostatEta;

  /// No description provided for @mirostatEtaDescription.
  ///
  /// In zh, this message translates to:
  /// **'比率'**
  String get mirostatEtaDescription;

  /// No description provided for @generationControl.
  ///
  /// In zh, this message translates to:
  /// **'生成'**
  String get generationControl;

  /// No description provided for @maxTokensDescription.
  ///
  /// In zh, this message translates to:
  /// **'令牌'**
  String get maxTokensDescription;

  /// No description provided for @seed.
  ///
  /// In zh, this message translates to:
  /// **'种子'**
  String get seed;

  /// No description provided for @seedDescription.
  ///
  /// In zh, this message translates to:
  /// **'用于可复现的随机种子。-1 = 随机。'**
  String get seedDescription;

  /// No description provided for @stopSequences.
  ///
  /// In zh, this message translates to:
  /// **'顶部'**
  String get stopSequences;

  /// No description provided for @noStopSequencesConfigured.
  ///
  /// In zh, this message translates to:
  /// **'配置'**
  String get noStopSequencesConfigured;

  /// No description provided for @stopSequencesDescription.
  ///
  /// In zh, this message translates to:
  /// **'生成'**
  String get stopSequencesDescription;

  /// No description provided for @resetConfirmation.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get resetConfirmation;

  /// No description provided for @reset.
  ///
  /// In zh, this message translates to:
  /// **'重置'**
  String get reset;

  /// No description provided for @settingsResetToDefaults.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settingsResetToDefaults;

  /// No description provided for @characterBackground.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get characterBackground;

  /// No description provided for @chatBackground.
  ///
  /// In zh, this message translates to:
  /// **'聊天'**
  String get chatBackground;

  /// No description provided for @clearBackground.
  ///
  /// In zh, this message translates to:
  /// **'清除'**
  String get clearBackground;

  /// No description provided for @gradientPresets.
  ///
  /// In zh, this message translates to:
  /// **'预设'**
  String get gradientPresets;

  /// No description provided for @solidColors.
  ///
  /// In zh, this message translates to:
  /// **'纯色'**
  String get solidColors;

  /// No description provided for @customImage.
  ///
  /// In zh, this message translates to:
  /// **'图像'**
  String get customImage;

  /// No description provided for @adjustments.
  ///
  /// In zh, this message translates to:
  /// **'调整'**
  String get adjustments;

  /// No description provided for @noBackgroundSelected.
  ///
  /// In zh, this message translates to:
  /// **'选择'**
  String get noBackgroundSelected;

  /// No description provided for @chooseImage.
  ///
  /// In zh, this message translates to:
  /// **'图像'**
  String get chooseImage;

  /// No description provided for @fromUrl.
  ///
  /// In zh, this message translates to:
  /// **'来自 URL'**
  String get fromUrl;

  /// No description provided for @localImage.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String localImage(Object filename);

  /// No description provided for @urlLabel.
  ///
  /// In zh, this message translates to:
  /// **'URL: {url}'**
  String urlLabel(Object url);

  /// No description provided for @noImage.
  ///
  /// In zh, this message translates to:
  /// **'图像'**
  String get noImage;

  /// No description provided for @opacity.
  ///
  /// In zh, this message translates to:
  /// **'透明度'**
  String get opacity;

  /// No description provided for @blurEffect.
  ///
  /// In zh, this message translates to:
  /// **'模糊效果'**
  String get blurEffect;

  /// No description provided for @applyBlurToBackground.
  ///
  /// In zh, this message translates to:
  /// **'应用'**
  String get applyBlurToBackground;

  /// No description provided for @blurAmount.
  ///
  /// In zh, this message translates to:
  /// **'模糊程度'**
  String get blurAmount;

  /// No description provided for @failedToLoadImage.
  ///
  /// In zh, this message translates to:
  /// **'加载'**
  String failedToLoadImage(Object error);

  /// No description provided for @imageUrl.
  ///
  /// In zh, this message translates to:
  /// **'图像'**
  String get imageUrl;

  /// No description provided for @enterImageUrl.
  ///
  /// In zh, this message translates to:
  /// **'图像'**
  String get enterImageUrl;

  /// No description provided for @apply.
  ///
  /// In zh, this message translates to:
  /// **'应用'**
  String get apply;

  /// No description provided for @enableCfgScale.
  ///
  /// In zh, this message translates to:
  /// **'启用'**
  String get enableCfgScale;

  /// No description provided for @cfgScaleDescription.
  ///
  /// In zh, this message translates to:
  /// **'文本'**
  String get cfgScaleDescription;

  /// No description provided for @globalSettings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get globalSettings;

  /// No description provided for @guidanceScale.
  ///
  /// In zh, this message translates to:
  /// **'引导系数'**
  String get guidanceScale;

  /// No description provided for @negativePrompt.
  ///
  /// In zh, this message translates to:
  /// **'提示'**
  String get negativePrompt;

  /// No description provided for @textToSteerAwayFrom.
  ///
  /// In zh, this message translates to:
  /// **'模型'**
  String get textToSteerAwayFrom;

  /// No description provided for @positivePromptOptional.
  ///
  /// In zh, this message translates to:
  /// **'提示'**
  String get positivePromptOptional;

  /// No description provided for @textToEnhanceInOutput.
  ///
  /// In zh, this message translates to:
  /// **'文本'**
  String get textToEnhanceInOutput;

  /// No description provided for @characterSettings.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get characterSettings;

  /// No description provided for @useCharacterSpecificSettings.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get useCharacterSpecificSettings;

  /// No description provided for @overrideGlobalForCharacter.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get overrideGlobalForCharacter;

  /// No description provided for @characterNegativePrompt.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get characterNegativePrompt;

  /// No description provided for @overrideGlobalNegativePrompt.
  ///
  /// In zh, this message translates to:
  /// **'提示'**
  String get overrideGlobalNegativePrompt;

  /// No description provided for @chatSettings.
  ///
  /// In zh, this message translates to:
  /// **'聊天'**
  String get chatSettings;

  /// No description provided for @chatSettingsDescription.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get chatSettingsDescription;

  /// No description provided for @chatNegativePrompt.
  ///
  /// In zh, this message translates to:
  /// **'聊天'**
  String get chatNegativePrompt;

  /// No description provided for @overrideForThisChat.
  ///
  /// In zh, this message translates to:
  /// **'聊天'**
  String get overrideForThisChat;

  /// No description provided for @chatPositivePrompt.
  ///
  /// In zh, this message translates to:
  /// **'聊天'**
  String get chatPositivePrompt;

  /// No description provided for @enhancementForThisChat.
  ///
  /// In zh, this message translates to:
  /// **'聊天'**
  String get enhancementForThisChat;

  /// No description provided for @promptCombineMode.
  ///
  /// In zh, this message translates to:
  /// **'提示'**
  String get promptCombineMode;

  /// No description provided for @replaceChatPromptOnly.
  ///
  /// In zh, this message translates to:
  /// **'聊天'**
  String get replaceChatPromptOnly;

  /// No description provided for @prependChatPlusGlobal.
  ///
  /// In zh, this message translates to:
  /// **'聊天'**
  String get prependChatPlusGlobal;

  /// No description provided for @appendGlobalPlusChat.
  ///
  /// In zh, this message translates to:
  /// **'聊天'**
  String get appendGlobalPlusChat;

  /// No description provided for @aboutCfgScale.
  ///
  /// In zh, this message translates to:
  /// **'关于 CFG Scale'**
  String get aboutCfgScale;

  /// No description provided for @aboutCfgScaleDescription.
  ///
  /// In zh, this message translates to:
  /// **'模型'**
  String get aboutCfgScaleDescription;

  /// No description provided for @cfgScaleHelp.
  ///
  /// In zh, this message translates to:
  /// **'帮助'**
  String get cfgScaleHelp;

  /// No description provided for @cfgScaleHelpContent.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get cfgScaleHelpContent;

  /// No description provided for @help.
  ///
  /// In zh, this message translates to:
  /// **'帮助'**
  String get help;

  /// No description provided for @sampleMessage1.
  ///
  /// In zh, this message translates to:
  /// **'你好！最近怎么样？'**
  String get sampleMessage1;

  /// No description provided for @sampleMessage2.
  ///
  /// In zh, this message translates to:
  /// **'我很好！'**
  String get sampleMessage2;

  /// No description provided for @general.
  ///
  /// In zh, this message translates to:
  /// **'通用'**
  String get general;

  /// No description provided for @enableImageGeneration.
  ///
  /// In zh, this message translates to:
  /// **'图像'**
  String get enableImageGeneration;

  /// No description provided for @generateImagesUsingAi.
  ///
  /// In zh, this message translates to:
  /// **'图像'**
  String get generateImagesUsingAi;

  /// No description provided for @imageGenerationProvider.
  ///
  /// In zh, this message translates to:
  /// **'图像'**
  String get imageGenerationProvider;

  /// No description provided for @apiEndpoint.
  ///
  /// In zh, this message translates to:
  /// **'API 端点'**
  String get apiEndpoint;

  /// No description provided for @notConfigured.
  ///
  /// In zh, this message translates to:
  /// **'配置'**
  String get notConfigured;

  /// No description provided for @defaultParameters.
  ///
  /// In zh, this message translates to:
  /// **'默认'**
  String get defaultParameters;

  /// No description provided for @imageSize.
  ///
  /// In zh, this message translates to:
  /// **'图像'**
  String get imageSize;

  /// No description provided for @steps.
  ///
  /// In zh, this message translates to:
  /// **'步数'**
  String get steps;

  /// No description provided for @sampler.
  ///
  /// In zh, this message translates to:
  /// **'采样器'**
  String get sampler;

  /// No description provided for @defaultNegativePrompt.
  ///
  /// In zh, this message translates to:
  /// **'提示'**
  String get defaultNegativePrompt;

  /// No description provided for @enterTermsToAvoid.
  ///
  /// In zh, this message translates to:
  /// **'图像'**
  String get enterTermsToAvoid;

  /// No description provided for @test.
  ///
  /// In zh, this message translates to:
  /// **'测试'**
  String get test;

  /// No description provided for @aboutImageGeneration.
  ///
  /// In zh, this message translates to:
  /// **'图像'**
  String get aboutImageGeneration;

  /// No description provided for @aboutImageGenerationDescription.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get aboutImageGenerationDescription;

  /// No description provided for @imagineCommand.
  ///
  /// In zh, this message translates to:
  /// **'/imagine 命令'**
  String get imagineCommand;

  /// No description provided for @imagineCommandUsage.
  ///
  /// In zh, this message translates to:
  /// **'提示'**
  String get imagineCommandUsage;

  /// No description provided for @stableDiffusion.
  ///
  /// In zh, this message translates to:
  /// **'Stable Diffusion'**
  String get stableDiffusion;

  /// No description provided for @stableDiffusionDescription.
  ///
  /// In zh, this message translates to:
  /// **'启用'**
  String get stableDiffusionDescription;

  /// No description provided for @dalle.
  ///
  /// In zh, this message translates to:
  /// **'DALL-E'**
  String get dalle;

  /// No description provided for @dalleDescription.
  ///
  /// In zh, this message translates to:
  /// **'图像'**
  String get dalleDescription;

  /// No description provided for @prompt.
  ///
  /// In zh, this message translates to:
  /// **'提示'**
  String get prompt;

  /// No description provided for @enterPromptToGenerate.
  ///
  /// In zh, this message translates to:
  /// **'提示'**
  String get enterPromptToGenerate;

  /// No description provided for @generate.
  ///
  /// In zh, this message translates to:
  /// **'比率'**
  String get generate;

  /// No description provided for @generating.
  ///
  /// In zh, this message translates to:
  /// **'生成中...'**
  String get generating;

  /// No description provided for @generationComplete.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get generationComplete;

  /// No description provided for @imageWouldBeDisplayed.
  ///
  /// In zh, this message translates to:
  /// **'图像'**
  String get imageWouldBeDisplayed;

  /// No description provided for @enableLogitBias.
  ///
  /// In zh, this message translates to:
  /// **'启用'**
  String get enableLogitBias;

  /// No description provided for @adjustTokenProbabilities.
  ///
  /// In zh, this message translates to:
  /// **'令牌'**
  String get adjustTokenProbabilities;

  /// No description provided for @presets.
  ///
  /// In zh, this message translates to:
  /// **'预设'**
  String get presets;

  /// No description provided for @activePresetLabel.
  ///
  /// In zh, this message translates to:
  /// **'预设'**
  String get activePresetLabel;

  /// No description provided for @none.
  ///
  /// In zh, this message translates to:
  /// **'无'**
  String get none;

  /// No description provided for @newPreset.
  ///
  /// In zh, this message translates to:
  /// **'预设'**
  String get newPreset;

  /// No description provided for @importPresetLabel.
  ///
  /// In zh, this message translates to:
  /// **'预设'**
  String get importPresetLabel;

  /// No description provided for @biasEntries.
  ///
  /// In zh, this message translates to:
  /// **'偏置条目'**
  String get biasEntries;

  /// No description provided for @noBiasEntries.
  ///
  /// In zh, this message translates to:
  /// **'暂无偏置条目'**
  String get noBiasEntries;

  /// No description provided for @addEntriesToAdjust.
  ///
  /// In zh, this message translates to:
  /// **'令牌'**
  String get addEntriesToAdjust;

  /// No description provided for @addEntry.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get addEntry;

  /// No description provided for @textOrToken.
  ///
  /// In zh, this message translates to:
  /// **'令牌'**
  String get textOrToken;

  /// No description provided for @textTokenHint.
  ///
  /// In zh, this message translates to:
  /// **'单词、{verbatim} 或 [1234]'**
  String textTokenHint(Object verbatim);

  /// No description provided for @bias.
  ///
  /// In zh, this message translates to:
  /// **'偏置'**
  String get bias;

  /// No description provided for @logitBiasHelp.
  ///
  /// In zh, this message translates to:
  /// **'帮助'**
  String get logitBiasHelp;

  /// No description provided for @presetCopiedToClipboard.
  ///
  /// In zh, this message translates to:
  /// **'预设'**
  String get presetCopiedToClipboard;

  /// No description provided for @exportPresetFailed.
  ///
  /// In zh, this message translates to:
  /// **'导出'**
  String exportPresetFailed(Object error);

  /// No description provided for @pastePresetJson.
  ///
  /// In zh, this message translates to:
  /// **'预设'**
  String get pastePresetJson;

  /// No description provided for @presetImportedSuccessfully.
  ///
  /// In zh, this message translates to:
  /// **'预设'**
  String get presetImportedSuccessfully;

  /// No description provided for @importPresetFailed.
  ///
  /// In zh, this message translates to:
  /// **'导入'**
  String importPresetFailed(Object error);

  /// No description provided for @rename.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get rename;

  /// No description provided for @deletePresetQuestion.
  ///
  /// In zh, this message translates to:
  /// **'预设'**
  String get deletePresetQuestion;

  /// No description provided for @moreOptions.
  ///
  /// In zh, this message translates to:
  /// **'更多选项'**
  String get moreOptions;

  /// No description provided for @loadPreset.
  ///
  /// In zh, this message translates to:
  /// **'预设'**
  String get loadPreset;

  /// No description provided for @saveAsPresetLabel.
  ///
  /// In zh, this message translates to:
  /// **'预设'**
  String get saveAsPresetLabel;

  /// No description provided for @exportPreset.
  ///
  /// In zh, this message translates to:
  /// **'预设'**
  String get exportPreset;

  /// No description provided for @resetToDefault.
  ///
  /// In zh, this message translates to:
  /// **'重置'**
  String get resetToDefault;

  /// No description provided for @dragToReorder.
  ///
  /// In zh, this message translates to:
  /// **'向量检索'**
  String get dragToReorder;

  /// No description provided for @deleted.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String deleted(Object name);

  /// No description provided for @imported.
  ///
  /// In zh, this message translates to:
  /// **'导入'**
  String imported(Object name);

  /// No description provided for @invalidPresetFormatMessage.
  ///
  /// In zh, this message translates to:
  /// **'预设'**
  String get invalidPresetFormatMessage;

  /// No description provided for @exportPresetTitle.
  ///
  /// In zh, this message translates to:
  /// **'预设'**
  String get exportPresetTitle;

  /// No description provided for @presetNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'预设'**
  String get presetNameLabel;

  /// No description provided for @pleaseEnterNameMessage.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get pleaseEnterNameMessage;

  /// No description provided for @saved.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String saved(Object name);

  /// No description provided for @saveFailedMessage.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String saveFailedMessage(Object error);

  /// No description provided for @resetToDefaultQuestion.
  ///
  /// In zh, this message translates to:
  /// **'重置'**
  String get resetToDefaultQuestion;

  /// No description provided for @resetToDefaultConfig.
  ///
  /// In zh, this message translates to:
  /// **'重置'**
  String get resetToDefaultConfig;

  /// No description provided for @promptManagerHelp.
  ///
  /// In zh, this message translates to:
  /// **'帮助'**
  String get promptManagerHelp;

  /// No description provided for @applied.
  ///
  /// In zh, this message translates to:
  /// **'预设'**
  String applied(Object name);

  /// No description provided for @showQuickReplies.
  ///
  /// In zh, this message translates to:
  /// **'显示'**
  String get showQuickReplies;

  /// No description provided for @displayQuickReplyButtons.
  ///
  /// In zh, this message translates to:
  /// **'聊天'**
  String get displayQuickReplyButtons;

  /// No description provided for @positionAboveInput.
  ///
  /// In zh, this message translates to:
  /// **'位置'**
  String get positionAboveInput;

  /// No description provided for @quickRepliesAboveInput.
  ///
  /// In zh, this message translates to:
  /// **'字段'**
  String get quickRepliesAboveInput;

  /// No description provided for @quickRepliesBelowInput.
  ///
  /// In zh, this message translates to:
  /// **'字段'**
  String get quickRepliesBelowInput;

  /// No description provided for @add.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get add;

  /// No description provided for @noQuickReplies.
  ///
  /// In zh, this message translates to:
  /// **'暂无快捷回复'**
  String get noQuickReplies;

  /// No description provided for @addYourFirstQuickReply.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get addYourFirstQuickReply;

  /// No description provided for @deleteQuickReplyQuestion.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String deleteQuickReplyQuestion(Object label);

  /// No description provided for @resetToDefaultQuestion2.
  ///
  /// In zh, this message translates to:
  /// **'默认'**
  String get resetToDefaultQuestion2;

  /// No description provided for @continueOrEmpty.
  ///
  /// In zh, this message translates to:
  /// **'消息'**
  String get continueOrEmpty;

  /// No description provided for @autoSendTooltip.
  ///
  /// In zh, this message translates to:
  /// **'自动'**
  String get autoSendTooltip;

  /// No description provided for @addQuickReply.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get addQuickReply;

  /// No description provided for @editQuickReplyLabel.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get editQuickReplyLabel;

  /// No description provided for @buttonLabel.
  ///
  /// In zh, this message translates to:
  /// **'标签'**
  String get buttonLabel;

  /// No description provided for @buttonLabelHint.
  ///
  /// In zh, this message translates to:
  /// **'例如：是、继续、思考...'**
  String get buttonLabelHint;

  /// No description provided for @messageLabel.
  ///
  /// In zh, this message translates to:
  /// **'消息'**
  String get messageLabel;

  /// No description provided for @leaveEmptyForContinue.
  ///
  /// In zh, this message translates to:
  /// **'留空表示继续操作'**
  String get leaveEmptyForContinue;

  /// No description provided for @supportsMacros.
  ///
  /// In zh, this message translates to:
  /// **'宏'**
  String supportsMacros(Object char, Object user);

  /// No description provided for @autoSendLabel.
  ///
  /// In zh, this message translates to:
  /// **'自动'**
  String get autoSendLabel;

  /// No description provided for @messageSentImmediately.
  ///
  /// In zh, this message translates to:
  /// **'消息'**
  String get messageSentImmediately;

  /// No description provided for @messageFillsInput.
  ///
  /// In zh, this message translates to:
  /// **'消息'**
  String get messageFillsInput;

  /// No description provided for @regexScripts.
  ///
  /// In zh, this message translates to:
  /// **'正则表达式'**
  String get regexScripts;

  /// No description provided for @addScript.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get addScript;

  /// No description provided for @addPresets.
  ///
  /// In zh, this message translates to:
  /// **'预设'**
  String get addPresets;

  /// No description provided for @clearAll.
  ///
  /// In zh, this message translates to:
  /// **'清除'**
  String get clearAll;

  /// No description provided for @enableRegexScripts.
  ///
  /// In zh, this message translates to:
  /// **'正则表达式'**
  String get enableRegexScripts;

  /// No description provided for @applyFindReplacePatterns.
  ///
  /// In zh, this message translates to:
  /// **'应用'**
  String get applyFindReplacePatterns;

  /// No description provided for @applyTo.
  ///
  /// In zh, this message translates to:
  /// **'应用'**
  String get applyTo;

  /// No description provided for @userInput.
  ///
  /// In zh, this message translates to:
  /// **'输入'**
  String get userInput;

  /// No description provided for @applyBeforeSending.
  ///
  /// In zh, this message translates to:
  /// **'应用'**
  String get applyBeforeSending;

  /// No description provided for @aiOutput.
  ///
  /// In zh, this message translates to:
  /// **'输出'**
  String get aiOutput;

  /// No description provided for @applyToAiResponses.
  ///
  /// In zh, this message translates to:
  /// **'应用'**
  String get applyToAiResponses;

  /// No description provided for @slashCommandsLabel.
  ///
  /// In zh, this message translates to:
  /// **'斜杠命令'**
  String get slashCommandsLabel;

  /// No description provided for @applyDuringCommandProcessing.
  ///
  /// In zh, this message translates to:
  /// **'应用'**
  String get applyDuringCommandProcessing;

  /// No description provided for @worldInfoLabel.
  ///
  /// In zh, this message translates to:
  /// **'世界'**
  String get worldInfoLabel;

  /// No description provided for @applyToWorldInfoEntries.
  ///
  /// In zh, this message translates to:
  /// **'世界'**
  String get applyToWorldInfoEntries;

  /// No description provided for @scriptsCount.
  ///
  /// In zh, this message translates to:
  /// **'计数'**
  String scriptsCount(Object count);

  /// No description provided for @noRegexScripts.
  ///
  /// In zh, this message translates to:
  /// **'正则表达式'**
  String get noRegexScripts;

  /// No description provided for @tapToAddOrUseMenu.
  ///
  /// In zh, this message translates to:
  /// **'预设'**
  String get tapToAddOrUseMenu;

  /// No description provided for @aboutRegexScripts.
  ///
  /// In zh, this message translates to:
  /// **'正则表达式'**
  String get aboutRegexScripts;

  /// No description provided for @aboutRegexScriptsDescription.
  ///
  /// In zh, this message translates to:
  /// **'正则表达式'**
  String get aboutRegexScriptsDescription;

  /// No description provided for @patternFormat.
  ///
  /// In zh, this message translates to:
  /// **'模式格式'**
  String get patternFormat;

  /// No description provided for @patternFormatDescription.
  ///
  /// In zh, this message translates to:
  /// **'使用 /pattern/flags 格式（例如 /hello/gi）或纯文本模式。标志：i=忽略大小写，m=多行，s=点匹配全部'**
  String get patternFormatDescription;

  /// No description provided for @presetScriptsAdded.
  ///
  /// In zh, this message translates to:
  /// **'预设'**
  String get presetScriptsAdded;

  /// No description provided for @deleteScriptQuestion.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String deleteScriptQuestion(Object name);

  /// No description provided for @clearAllScripts.
  ///
  /// In zh, this message translates to:
  /// **'清除'**
  String get clearAllScripts;

  /// No description provided for @clearAllScriptsQuestion.
  ///
  /// In zh, this message translates to:
  /// **'正则表达式'**
  String get clearAllScriptsQuestion;

  /// No description provided for @importScripts.
  ///
  /// In zh, this message translates to:
  /// **'导入'**
  String get importScripts;

  /// No description provided for @pasteJsonArray.
  ///
  /// In zh, this message translates to:
  /// **'粘贴脚本的 JSON 数组'**
  String get pasteJsonArray;

  /// No description provided for @importedCount.
  ///
  /// In zh, this message translates to:
  /// **'导入'**
  String importedCount(Object count);

  /// No description provided for @exportScripts.
  ///
  /// In zh, this message translates to:
  /// **'导出'**
  String get exportScripts;

  /// No description provided for @newScript.
  ///
  /// In zh, this message translates to:
  /// **'新建脚本'**
  String get newScript;

  /// No description provided for @editScript.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get editScript;

  /// No description provided for @scriptName.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get scriptName;

  /// No description provided for @descriptionOptionalLabel.
  ///
  /// In zh, this message translates to:
  /// **'描述'**
  String get descriptionOptionalLabel;

  /// No description provided for @findPattern.
  ///
  /// In zh, this message translates to:
  /// **'查找模式'**
  String get findPattern;

  /// No description provided for @patternOrPlainPattern.
  ///
  /// In zh, this message translates to:
  /// **'/pattern/flags 或纯文本模式'**
  String get patternOrPlainPattern;

  /// No description provided for @replaceWith.
  ///
  /// In zh, this message translates to:
  /// **'替换为'**
  String get replaceWith;

  /// No description provided for @useCaptureGroups.
  ///
  /// In zh, this message translates to:
  /// **'使用 \$1、\$2 表示捕获组'**
  String get useCaptureGroups;

  /// No description provided for @applyToLabel.
  ///
  /// In zh, this message translates to:
  /// **'应用'**
  String get applyToLabel;

  /// No description provided for @options.
  ///
  /// In zh, this message translates to:
  /// **'选项'**
  String get options;

  /// No description provided for @markdownOnly.
  ///
  /// In zh, this message translates to:
  /// **'仅 Markdown'**
  String get markdownOnly;

  /// No description provided for @onlyApplyDuringMarkdown.
  ///
  /// In zh, this message translates to:
  /// **'应用'**
  String get onlyApplyDuringMarkdown;

  /// No description provided for @promptOnly.
  ///
  /// In zh, this message translates to:
  /// **'提示'**
  String get promptOnly;

  /// No description provided for @onlyApplyDuringPrompt.
  ///
  /// In zh, this message translates to:
  /// **'应用'**
  String get onlyApplyDuringPrompt;

  /// No description provided for @runOnEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get runOnEdit;

  /// No description provided for @applyWhenEditingMessages.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get applyWhenEditingMessages;

  /// No description provided for @macroSubstitution.
  ///
  /// In zh, this message translates to:
  /// **'宏'**
  String get macroSubstitution;

  /// No description provided for @nameAndPatternRequired.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get nameAndPatternRequired;

  /// No description provided for @patternLabel.
  ///
  /// In zh, this message translates to:
  /// **'模式'**
  String get patternLabel;

  /// No description provided for @patternHint.
  ///
  /// In zh, this message translates to:
  /// **'/pattern/flags'**
  String get patternHint;

  /// No description provided for @testString.
  ///
  /// In zh, this message translates to:
  /// **'测试'**
  String get testString;

  /// No description provided for @replacementLabel.
  ///
  /// In zh, this message translates to:
  /// **'替换内容'**
  String get replacementLabel;

  /// No description provided for @replacementHint.
  ///
  /// In zh, this message translates to:
  /// **'\$1、\$2、{match}'**
  String replacementHint(Object match);

  /// No description provided for @testButton.
  ///
  /// In zh, this message translates to:
  /// **'测试'**
  String get testButton;

  /// No description provided for @matchesCount.
  ///
  /// In zh, this message translates to:
  /// **'计数'**
  String matchesCount(Object count);

  /// No description provided for @errorLabel.
  ///
  /// In zh, this message translates to:
  /// **'错误'**
  String get errorLabel;

  /// No description provided for @resultLabel.
  ///
  /// In zh, this message translates to:
  /// **'结果'**
  String get resultLabel;

  /// No description provided for @expressionSprites.
  ///
  /// In zh, this message translates to:
  /// **'立绘'**
  String get expressionSprites;

  /// No description provided for @enableSprites.
  ///
  /// In zh, this message translates to:
  /// **'启用'**
  String get enableSprites;

  /// No description provided for @showCharacterExpressions.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get showCharacterExpressions;

  /// No description provided for @display.
  ///
  /// In zh, this message translates to:
  /// **'显示'**
  String get display;

  /// No description provided for @spriteSize.
  ///
  /// In zh, this message translates to:
  /// **'立绘'**
  String get spriteSize;

  /// No description provided for @position.
  ///
  /// In zh, this message translates to:
  /// **'位置'**
  String get position;

  /// No description provided for @whereToDisplaySprites.
  ///
  /// In zh, this message translates to:
  /// **'立绘'**
  String get whereToDisplaySprites;

  /// No description provided for @left.
  ///
  /// In zh, this message translates to:
  /// **'左侧'**
  String get left;

  /// No description provided for @right.
  ///
  /// In zh, this message translates to:
  /// **'右侧'**
  String get right;

  /// No description provided for @center.
  ///
  /// In zh, this message translates to:
  /// **'居中'**
  String get center;

  /// No description provided for @floatingLeft.
  ///
  /// In zh, this message translates to:
  /// **'左侧'**
  String get floatingLeft;

  /// No description provided for @floatingRight.
  ///
  /// In zh, this message translates to:
  /// **'右侧'**
  String get floatingRight;

  /// No description provided for @animation.
  ///
  /// In zh, this message translates to:
  /// **'动画'**
  String get animation;

  /// No description provided for @animateTransitions.
  ///
  /// In zh, this message translates to:
  /// **'过渡'**
  String get animateTransitions;

  /// No description provided for @smoothFadeWhenSpriteChanges.
  ///
  /// In zh, this message translates to:
  /// **'立绘'**
  String get smoothFadeWhenSpriteChanges;

  /// No description provided for @transitionDuration.
  ///
  /// In zh, this message translates to:
  /// **'持续时间'**
  String get transitionDuration;

  /// No description provided for @showDuringStreaming.
  ///
  /// In zh, this message translates to:
  /// **'显示'**
  String get showDuringStreaming;

  /// No description provided for @displaySpritesWhileGenerating.
  ///
  /// In zh, this message translates to:
  /// **'立绘'**
  String get displaySpritesWhileGenerating;

  /// No description provided for @emotionDetection.
  ///
  /// In zh, this message translates to:
  /// **'情绪'**
  String get emotionDetection;

  /// No description provided for @howItWorks.
  ///
  /// In zh, this message translates to:
  /// **'工作原理'**
  String get howItWorks;

  /// No description provided for @spriteEmotionDetectionDescription.
  ///
  /// In zh, this message translates to:
  /// **'消息'**
  String get spriteEmotionDetectionDescription;

  /// No description provided for @supportedEmotions.
  ///
  /// In zh, this message translates to:
  /// **'情绪'**
  String get supportedEmotions;

  /// No description provided for @characterSprites.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String characterSprites(Object name);

  /// No description provided for @importFromFolder.
  ///
  /// In zh, this message translates to:
  /// **'导入'**
  String get importFromFolder;

  /// No description provided for @deleteAllSprites.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get deleteAllSprites;

  /// No description provided for @addSprite.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get addSprite;

  /// No description provided for @spritesCount.
  ///
  /// In zh, this message translates to:
  /// **'立绘'**
  String spritesCount(Object count);

  /// No description provided for @defaultEmotion.
  ///
  /// In zh, this message translates to:
  /// **'情绪'**
  String defaultEmotion(Object emotion);

  /// No description provided for @noSpritesYet.
  ///
  /// In zh, this message translates to:
  /// **'立绘'**
  String get noSpritesYet;

  /// No description provided for @addExpressionImages.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get addExpressionImages;

  /// No description provided for @selectEmotion.
  ///
  /// In zh, this message translates to:
  /// **'选择'**
  String get selectEmotion;

  /// No description provided for @addedSpriteEmotion.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String addedSpriteEmotion(Object emotion);

  /// No description provided for @setAsDefaultEmotion.
  ///
  /// In zh, this message translates to:
  /// **'默认'**
  String get setAsDefaultEmotion;

  /// No description provided for @changeEmotion.
  ///
  /// In zh, this message translates to:
  /// **'情绪'**
  String get changeEmotion;

  /// No description provided for @deleteSprite.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get deleteSprite;

  /// No description provided for @deleteSpriteConfirmation.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String deleteSpriteConfirmation(Object emotion);

  /// No description provided for @deleteAllSpritesConfirmation.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get deleteAllSpritesConfirmation;

  /// No description provided for @importSprites.
  ///
  /// In zh, this message translates to:
  /// **'导入'**
  String get importSprites;

  /// No description provided for @importSpritesDescription.
  ///
  /// In zh, this message translates to:
  /// **'导入'**
  String get importSpritesDescription;

  /// No description provided for @supportedFormatsSprites.
  ///
  /// In zh, this message translates to:
  /// **'支持的格式：PNG、JPG、GIF、WebP'**
  String get supportedFormatsSprites;

  /// No description provided for @selectFolder.
  ///
  /// In zh, this message translates to:
  /// **'文件夹'**
  String get selectFolder;

  /// No description provided for @folderImportRequiresPackage.
  ///
  /// In zh, this message translates to:
  /// **'导入'**
  String get folderImportRequiresPackage;

  /// No description provided for @appStatistics.
  ///
  /// In zh, this message translates to:
  /// **'统计'**
  String get appStatistics;

  /// No description provided for @chatStatistics.
  ///
  /// In zh, this message translates to:
  /// **'聊天'**
  String get chatStatistics;

  /// No description provided for @resetStatistics.
  ///
  /// In zh, this message translates to:
  /// **'重置'**
  String get resetStatistics;

  /// No description provided for @resetStatisticsConfirmation.
  ///
  /// In zh, this message translates to:
  /// **'重置'**
  String get resetStatisticsConfirmation;

  /// No description provided for @statisticsReset.
  ///
  /// In zh, this message translates to:
  /// **'重置'**
  String get statisticsReset;

  /// No description provided for @overview.
  ///
  /// In zh, this message translates to:
  /// **'查看'**
  String get overview;

  /// No description provided for @firstUsed.
  ///
  /// In zh, this message translates to:
  /// **'首次使用'**
  String get firstUsed;

  /// No description provided for @unknown.
  ///
  /// In zh, this message translates to:
  /// **'未知'**
  String get unknown;

  /// No description provided for @totalGroups.
  ///
  /// In zh, this message translates to:
  /// **'总计'**
  String get totalGroups;

  /// No description provided for @totalGenerations.
  ///
  /// In zh, this message translates to:
  /// **'生成'**
  String get totalGenerations;

  /// No description provided for @tokenUsage.
  ///
  /// In zh, this message translates to:
  /// **'令牌'**
  String get tokenUsage;

  /// No description provided for @totalTokensUsed.
  ///
  /// In zh, this message translates to:
  /// **'令牌'**
  String get totalTokensUsed;

  /// No description provided for @avgTokensPerGeneration.
  ///
  /// In zh, this message translates to:
  /// **'令牌'**
  String get avgTokensPerGeneration;

  /// No description provided for @performance.
  ///
  /// In zh, this message translates to:
  /// **'性能'**
  String get performance;

  /// No description provided for @totalGenerationTime.
  ///
  /// In zh, this message translates to:
  /// **'生成'**
  String get totalGenerationTime;

  /// No description provided for @avgGenerationTime.
  ///
  /// In zh, this message translates to:
  /// **'生成'**
  String get avgGenerationTime;

  /// No description provided for @userMessages.
  ///
  /// In zh, this message translates to:
  /// **'消息'**
  String get userMessages;

  /// No description provided for @assistantMessages.
  ///
  /// In zh, this message translates to:
  /// **'消息'**
  String get assistantMessages;

  /// No description provided for @systemMessages.
  ///
  /// In zh, this message translates to:
  /// **'消息'**
  String get systemMessages;

  /// No description provided for @timeline.
  ///
  /// In zh, this message translates to:
  /// **'时间线'**
  String get timeline;

  /// No description provided for @firstMessage_.
  ///
  /// In zh, this message translates to:
  /// **'消息'**
  String get firstMessage_;

  /// No description provided for @lastMessage.
  ///
  /// In zh, this message translates to:
  /// **'消息'**
  String get lastMessage;

  /// No description provided for @chatDuration.
  ///
  /// In zh, this message translates to:
  /// **'聊天'**
  String get chatDuration;

  /// No description provided for @promptTokens.
  ///
  /// In zh, this message translates to:
  /// **'令牌'**
  String get promptTokens;

  /// No description provided for @completionTokens.
  ///
  /// In zh, this message translates to:
  /// **'令牌'**
  String get completionTokens;

  /// No description provided for @avgTokensPerMessage.
  ///
  /// In zh, this message translates to:
  /// **'令牌'**
  String get avgTokensPerMessage;

  /// No description provided for @generationPerformance.
  ///
  /// In zh, this message translates to:
  /// **'生成'**
  String get generationPerformance;

  /// No description provided for @generationCount.
  ///
  /// In zh, this message translates to:
  /// **'生成'**
  String get generationCount;

  /// No description provided for @speechToText.
  ///
  /// In zh, this message translates to:
  /// **'文本'**
  String get speechToText;

  /// No description provided for @enableStt.
  ///
  /// In zh, this message translates to:
  /// **'启用'**
  String get enableStt;

  /// No description provided for @useVoiceInputForMessages.
  ///
  /// In zh, this message translates to:
  /// **'语音'**
  String get useVoiceInputForMessages;

  /// No description provided for @autoSendStt.
  ///
  /// In zh, this message translates to:
  /// **'自动'**
  String get autoSendStt;

  /// No description provided for @automaticallySendAfterSpeaking.
  ///
  /// In zh, this message translates to:
  /// **'消息'**
  String get automaticallySendAfterSpeaking;

  /// No description provided for @continuousListening.
  ///
  /// In zh, this message translates to:
  /// **'列表'**
  String get continuousListening;

  /// No description provided for @keepListeningAfterPhrase.
  ///
  /// In zh, this message translates to:
  /// **'列表'**
  String get keepListeningAfterPhrase;

  /// No description provided for @showPartialResults.
  ///
  /// In zh, this message translates to:
  /// **'显示'**
  String get showPartialResults;

  /// No description provided for @displayTextAsYouSpeak.
  ///
  /// In zh, this message translates to:
  /// **'文本'**
  String get displayTextAsYouSpeak;

  /// No description provided for @sttProvider.
  ///
  /// In zh, this message translates to:
  /// **'语音识别服务商'**
  String get sttProvider;

  /// No description provided for @recognitionLanguage.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get recognitionLanguage;

  /// No description provided for @testVoiceInput.
  ///
  /// In zh, this message translates to:
  /// **'测试'**
  String get testVoiceInput;

  /// No description provided for @stopListening.
  ///
  /// In zh, this message translates to:
  /// **'列表'**
  String get stopListening;

  /// No description provided for @tapToStop.
  ///
  /// In zh, this message translates to:
  /// **'顶部'**
  String get tapToStop;

  /// No description provided for @tapToTestSpeechRecognition.
  ///
  /// In zh, this message translates to:
  /// **'测试'**
  String get tapToTestSpeechRecognition;

  /// No description provided for @final_.
  ///
  /// In zh, this message translates to:
  /// **'最终'**
  String get final_;

  /// No description provided for @listening.
  ///
  /// In zh, this message translates to:
  /// **'列表'**
  String get listening;

  /// No description provided for @aboutStt.
  ///
  /// In zh, this message translates to:
  /// **'关于 STT'**
  String get aboutStt;

  /// No description provided for @aboutSttDescription.
  ///
  /// In zh, this message translates to:
  /// **'聊天'**
  String get aboutSttDescription;

  /// No description provided for @systemStt.
  ///
  /// In zh, this message translates to:
  /// **'系统'**
  String get systemStt;

  /// No description provided for @systemSttDescription.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get systemSttDescription;

  /// No description provided for @whisper.
  ///
  /// In zh, this message translates to:
  /// **'Whisper'**
  String get whisper;

  /// No description provided for @whisperDescription.
  ///
  /// In zh, this message translates to:
  /// **'模型'**
  String get whisperDescription;

  /// No description provided for @voiceInput.
  ///
  /// In zh, this message translates to:
  /// **'语音'**
  String get voiceInput;

  /// No description provided for @speechRecognitionNotAvailable.
  ///
  /// In zh, this message translates to:
  /// **'识别'**
  String get speechRecognitionNotAvailable;

  /// No description provided for @themes.
  ///
  /// In zh, this message translates to:
  /// **'主题'**
  String get themes;

  /// No description provided for @createCustomTheme.
  ///
  /// In zh, this message translates to:
  /// **'主题'**
  String get createCustomTheme;

  /// No description provided for @builtInThemes.
  ///
  /// In zh, this message translates to:
  /// **'主题'**
  String get builtInThemes;

  /// No description provided for @preview.
  ///
  /// In zh, this message translates to:
  /// **'查看'**
  String get preview;

  /// No description provided for @chatPreview.
  ///
  /// In zh, this message translates to:
  /// **'聊天'**
  String get chatPreview;

  /// No description provided for @helloHowCanIHelp.
  ///
  /// In zh, this message translates to:
  /// **'帮助'**
  String get helloHowCanIHelp;

  /// No description provided for @tellMeAStory.
  ///
  /// In zh, this message translates to:
  /// **'给我讲个故事吧！'**
  String get tellMeAStory;

  /// No description provided for @typeAMessage.
  ///
  /// In zh, this message translates to:
  /// **'消息'**
  String get typeAMessage;

  /// No description provided for @createTheme.
  ///
  /// In zh, this message translates to:
  /// **'主题'**
  String get createTheme;

  /// No description provided for @editTheme.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get editTheme;

  /// No description provided for @deleteTheme.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get deleteTheme;

  /// No description provided for @deleteThemeConfirmation.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String deleteThemeConfirmation(Object name);

  /// No description provided for @themeName.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get themeName;

  /// No description provided for @background.
  ///
  /// In zh, this message translates to:
  /// **'背景'**
  String get background;

  /// No description provided for @surface.
  ///
  /// In zh, this message translates to:
  /// **'表面'**
  String get surface;

  /// No description provided for @card.
  ///
  /// In zh, this message translates to:
  /// **'卡片'**
  String get card;

  /// No description provided for @selectThemeColor.
  ///
  /// In zh, this message translates to:
  /// **'选择'**
  String selectThemeColor(Object label);

  /// No description provided for @hexColor.
  ///
  /// In zh, this message translates to:
  /// **'十六进制颜色'**
  String get hexColor;

  /// No description provided for @tokenizerSettings.
  ///
  /// In zh, this message translates to:
  /// **'令牌'**
  String get tokenizerSettings;

  /// No description provided for @tokenizerHelp.
  ///
  /// In zh, this message translates to:
  /// **'帮助'**
  String get tokenizerHelp;

  /// No description provided for @tokenizerLabel.
  ///
  /// In zh, this message translates to:
  /// **'令牌'**
  String get tokenizerLabel;

  /// No description provided for @showTokenCount.
  ///
  /// In zh, this message translates to:
  /// **'令牌'**
  String get showTokenCount;

  /// No description provided for @displayTokenCountInInput.
  ///
  /// In zh, this message translates to:
  /// **'聊天'**
  String get displayTokenCountInInput;

  /// No description provided for @showTokenVisualization.
  ///
  /// In zh, this message translates to:
  /// **'令牌'**
  String get showTokenVisualization;

  /// No description provided for @highlightIndividualTokens.
  ///
  /// In zh, this message translates to:
  /// **'令牌'**
  String get highlightIndividualTokens;

  /// No description provided for @cacheResults.
  ///
  /// In zh, this message translates to:
  /// **'缓存'**
  String get cacheResults;

  /// No description provided for @cacheTokenizationForPerformance.
  ///
  /// In zh, this message translates to:
  /// **'令牌'**
  String get cacheTokenizationForPerformance;

  /// No description provided for @tokenVisualization.
  ///
  /// In zh, this message translates to:
  /// **'令牌'**
  String get tokenVisualization;

  /// No description provided for @enterTextToTokenize.
  ///
  /// In zh, this message translates to:
  /// **'令牌'**
  String get enterTextToTokenize;

  /// No description provided for @typePasteTextHere.
  ///
  /// In zh, this message translates to:
  /// **'文本'**
  String get typePasteTextHere;

  /// No description provided for @quickEstimate.
  ///
  /// In zh, this message translates to:
  /// **'快速估算'**
  String get quickEstimate;

  /// No description provided for @approximateTokens.
  ///
  /// In zh, this message translates to:
  /// **'令牌'**
  String approximateTokens(Object count);

  /// No description provided for @chars.
  ///
  /// In zh, this message translates to:
  /// **'计数'**
  String chars(Object count);

  /// No description provided for @statisticsLabel.
  ///
  /// In zh, this message translates to:
  /// **'统计'**
  String get statisticsLabel;

  /// No description provided for @unique.
  ///
  /// In zh, this message translates to:
  /// **'唯一'**
  String get unique;

  /// No description provided for @charsPerToken.
  ///
  /// In zh, this message translates to:
  /// **'令牌'**
  String get charsPerToken;

  /// No description provided for @avgLength.
  ///
  /// In zh, this message translates to:
  /// **'平均长度'**
  String get avgLength;

  /// No description provided for @longest.
  ///
  /// In zh, this message translates to:
  /// **'最长'**
  String get longest;

  /// No description provided for @shortest.
  ///
  /// In zh, this message translates to:
  /// **'测试'**
  String get shortest;

  /// No description provided for @mostCommonTokens.
  ///
  /// In zh, this message translates to:
  /// **'令牌'**
  String get mostCommonTokens;

  /// No description provided for @tokenBreakdown.
  ///
  /// In zh, this message translates to:
  /// **'令牌'**
  String get tokenBreakdown;

  /// No description provided for @tokensCount.
  ///
  /// In zh, this message translates to:
  /// **'令牌'**
  String tokensCount(Object count);

  /// No description provided for @tokenIdLength.
  ///
  /// In zh, this message translates to:
  /// **'令牌'**
  String tokenIdLength(Object id, Object length);

  /// No description provided for @translationSettings.
  ///
  /// In zh, this message translates to:
  /// **'翻译'**
  String get translationSettings;

  /// No description provided for @enableTranslation.
  ///
  /// In zh, this message translates to:
  /// **'启用'**
  String get enableTranslation;

  /// No description provided for @translateMessagesAutomatically.
  ///
  /// In zh, this message translates to:
  /// **'消息'**
  String get translateMessagesAutomatically;

  /// No description provided for @translationProvider.
  ///
  /// In zh, this message translates to:
  /// **'翻译'**
  String get translationProvider;

  /// No description provided for @sourceLanguage.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get sourceLanguage;

  /// No description provided for @targetLanguage.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get targetLanguage;

  /// No description provided for @autoDetect.
  ///
  /// In zh, this message translates to:
  /// **'自动'**
  String get autoDetect;

  /// No description provided for @translateUserMessages.
  ///
  /// In zh, this message translates to:
  /// **'消息'**
  String get translateUserMessages;

  /// No description provided for @translateAiResponses.
  ///
  /// In zh, this message translates to:
  /// **'翻译 AI 回复'**
  String get translateAiResponses;

  /// No description provided for @textToSpeech.
  ///
  /// In zh, this message translates to:
  /// **'文本'**
  String get textToSpeech;

  /// No description provided for @enableTts.
  ///
  /// In zh, this message translates to:
  /// **'启用'**
  String get enableTts;

  /// No description provided for @readAiResponsesAloud.
  ///
  /// In zh, this message translates to:
  /// **'朗读 AI 回复'**
  String get readAiResponsesAloud;

  /// No description provided for @ttsProvider.
  ///
  /// In zh, this message translates to:
  /// **'语音合成服务商'**
  String get ttsProvider;

  /// No description provided for @voiceSettings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get voiceSettings;

  /// No description provided for @voice.
  ///
  /// In zh, this message translates to:
  /// **'语音'**
  String get voice;

  /// No description provided for @speed.
  ///
  /// In zh, this message translates to:
  /// **'速度'**
  String get speed;

  /// No description provided for @pitch.
  ///
  /// In zh, this message translates to:
  /// **'音调'**
  String get pitch;

  /// No description provided for @volume.
  ///
  /// In zh, this message translates to:
  /// **'音量'**
  String get volume;

  /// No description provided for @autoPlay.
  ///
  /// In zh, this message translates to:
  /// **'自动'**
  String get autoPlay;

  /// No description provided for @automaticallyPlayResponses.
  ///
  /// In zh, this message translates to:
  /// **'自动'**
  String get automaticallyPlayResponses;

  /// No description provided for @testVoice.
  ///
  /// In zh, this message translates to:
  /// **'测试'**
  String get testVoice;

  /// No description provided for @chatVariables.
  ///
  /// In zh, this message translates to:
  /// **'聊天'**
  String get chatVariables;

  /// No description provided for @variableSystem.
  ///
  /// In zh, this message translates to:
  /// **'变量'**
  String get variableSystem;

  /// No description provided for @globalVariables.
  ///
  /// In zh, this message translates to:
  /// **'变量'**
  String get globalVariables;

  /// No description provided for @globalVariablesCount.
  ///
  /// In zh, this message translates to:
  /// **'变量'**
  String globalVariablesCount(Object count);

  /// No description provided for @localVariables.
  ///
  /// In zh, this message translates to:
  /// **'变量'**
  String get localVariables;

  /// No description provided for @localVariablesCount.
  ///
  /// In zh, this message translates to:
  /// **'变量'**
  String localVariablesCount(Object count);

  /// No description provided for @addVariable.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get addVariable;

  /// No description provided for @variableName.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get variableName;

  /// No description provided for @variableValue.
  ///
  /// In zh, this message translates to:
  /// **'变量'**
  String get variableValue;

  /// No description provided for @scope.
  ///
  /// In zh, this message translates to:
  /// **'作用域'**
  String get scope;

  /// No description provided for @global.
  ///
  /// In zh, this message translates to:
  /// **'全局'**
  String get global;

  /// No description provided for @vectorStorageRag.
  ///
  /// In zh, this message translates to:
  /// **'向量检索'**
  String get vectorStorageRag;

  /// No description provided for @enableRag.
  ///
  /// In zh, this message translates to:
  /// **'向量检索'**
  String get enableRag;

  /// No description provided for @useVectorStorageForContext.
  ///
  /// In zh, this message translates to:
  /// **'向量检索'**
  String get useVectorStorageForContext;

  /// No description provided for @collections.
  ///
  /// In zh, this message translates to:
  /// **'集合'**
  String get collections;

  /// No description provided for @createCollection.
  ///
  /// In zh, this message translates to:
  /// **'创建'**
  String get createCollection;

  /// No description provided for @collectionName.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get collectionName;

  /// No description provided for @embeddingProvider.
  ///
  /// In zh, this message translates to:
  /// **'嵌入向量服务商'**
  String get embeddingProvider;

  /// No description provided for @embeddingModel.
  ///
  /// In zh, this message translates to:
  /// **'模型'**
  String get embeddingModel;

  /// No description provided for @chunkSize.
  ///
  /// In zh, this message translates to:
  /// **'大小'**
  String get chunkSize;

  /// No description provided for @chunkOverlap.
  ///
  /// In zh, this message translates to:
  /// **'分块重叠'**
  String get chunkOverlap;

  /// No description provided for @topKResults.
  ///
  /// In zh, this message translates to:
  /// **'结果'**
  String get topKResults;

  /// No description provided for @similarityThreshold.
  ///
  /// In zh, this message translates to:
  /// **'阈值'**
  String get similarityThreshold;

  /// No description provided for @characterEditor.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get characterEditor;

  /// No description provided for @basic.
  ///
  /// In zh, this message translates to:
  /// **'基础'**
  String get basic;

  /// No description provided for @prompts.
  ///
  /// In zh, this message translates to:
  /// **'提示'**
  String get prompts;

  /// No description provided for @meta.
  ///
  /// In zh, this message translates to:
  /// **'Meta'**
  String get meta;

  /// No description provided for @nameRequired.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get nameRequired;

  /// No description provided for @characterName.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get characterName;

  /// No description provided for @nameIsRequired.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get nameIsRequired;

  /// No description provided for @characterDescription.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get characterDescription;

  /// No description provided for @characterPersonalityTraits.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get characterPersonalityTraits;

  /// No description provided for @currentCircumstancesContext.
  ///
  /// In zh, this message translates to:
  /// **'文本'**
  String get currentCircumstancesContext;

  /// No description provided for @customInstructionsSystemMessage.
  ///
  /// In zh, this message translates to:
  /// **'消息'**
  String get customInstructionsSystemMessage;

  /// No description provided for @systemPromptHint.
  ///
  /// In zh, this message translates to:
  /// **'你是 {char}。你将...'**
  String systemPromptHint(Object char);

  /// No description provided for @instructionsInsertedAfterHistory.
  ///
  /// In zh, this message translates to:
  /// **'聊天'**
  String get instructionsInsertedAfterHistory;

  /// No description provided for @postHistoryInstructionsHint.
  ///
  /// In zh, this message translates to:
  /// **'以 {char} 的身份继续角色扮演...'**
  String postHistoryInstructionsHint(Object char);

  /// No description provided for @firstMessageGreeting.
  ///
  /// In zh, this message translates to:
  /// **'消息'**
  String get firstMessageGreeting;

  /// No description provided for @firstMessageSentByCharacter.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get firstMessageSentByCharacter;

  /// No description provided for @firstMessageHint.
  ///
  /// In zh, this message translates to:
  /// **'*走进房间* 你好，{user}！'**
  String firstMessageHint(Object user);

  /// No description provided for @alternateGreetingsCanSwipe.
  ///
  /// In zh, this message translates to:
  /// **'消息'**
  String get alternateGreetingsCanSwipe;

  /// No description provided for @greeting.
  ///
  /// In zh, this message translates to:
  /// **'问候语 {index}'**
  String greeting(Object index);

  /// No description provided for @alternativeGreetingMessage.
  ///
  /// In zh, this message translates to:
  /// **'消息'**
  String get alternativeGreetingMessage;

  /// No description provided for @removeGreeting.
  ///
  /// In zh, this message translates to:
  /// **'移除'**
  String get removeGreeting;

  /// No description provided for @moveUp.
  ///
  /// In zh, this message translates to:
  /// **'上移'**
  String get moveUp;

  /// No description provided for @moveDown.
  ///
  /// In zh, this message translates to:
  /// **'下移'**
  String get moveDown;

  /// No description provided for @noAlternateGreetings.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get noAlternateGreetings;

  /// No description provided for @exampleDialogueDemonstrate.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String exampleDialogueDemonstrate(Object char, Object user);

  /// No description provided for @exampleMessagesHint.
  ///
  /// In zh, this message translates to:
  /// **'<START>\\n{user}: 你好吗？\\n{char}: 我很好，谢谢关心！'**
  String exampleMessagesHint(Object char, Object user);

  /// No description provided for @creatorNotesNotSentToAi.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get creatorNotesNotSentToAi;

  /// No description provided for @creatorNotesHint.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get creatorNotesHint;

  /// No description provided for @tagsCommaSeparated.
  ///
  /// In zh, this message translates to:
  /// **'比率'**
  String get tagsCommaSeparated;

  /// No description provided for @tagsHint.
  ///
  /// In zh, this message translates to:
  /// **'奇幻、女性、冒险'**
  String get tagsHint;

  /// No description provided for @creator.
  ///
  /// In zh, this message translates to:
  /// **'创作者'**
  String get creator;

  /// No description provided for @yourNameOrUsername.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get yourNameOrUsername;

  /// No description provided for @versionNumber.
  ///
  /// In zh, this message translates to:
  /// **'1.0.0'**
  String get versionNumber;

  /// No description provided for @characterInfo.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get characterInfo;

  /// No description provided for @characterId.
  ///
  /// In zh, this message translates to:
  /// **'ID: {id}'**
  String characterId(Object id);

  /// No description provided for @created.
  ///
  /// In zh, this message translates to:
  /// **'创建'**
  String created(Object date);

  /// No description provided for @modified.
  ///
  /// In zh, this message translates to:
  /// **'修改于：{date}'**
  String modified(Object date);

  /// No description provided for @characterSavedSuccessfully.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get characterSavedSuccessfully;

  /// No description provided for @failedToSaveCharacter.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String failedToSaveCharacter(Object error);

  /// No description provided for @addAlternateGreeting.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get addAlternateGreeting;

  /// No description provided for @groupInfo.
  ///
  /// In zh, this message translates to:
  /// **'信息'**
  String get groupInfo;

  /// No description provided for @responseMode.
  ///
  /// In zh, this message translates to:
  /// **'模式'**
  String get responseMode;

  /// No description provided for @howCharactersTakeTurns.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get howCharactersTakeTurns;

  /// No description provided for @sequential.
  ///
  /// In zh, this message translates to:
  /// **'顺序'**
  String get sequential;

  /// No description provided for @charactersRespondInOrder.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get charactersRespondInOrder;

  /// No description provided for @random.
  ///
  /// In zh, this message translates to:
  /// **'随机'**
  String get random;

  /// No description provided for @randomCharacterResponds.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get randomCharacterResponds;

  /// No description provided for @allAtOnce.
  ///
  /// In zh, this message translates to:
  /// **'一次全部'**
  String get allAtOnce;

  /// No description provided for @allNonMutedCharactersRespond.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get allNonMutedCharactersRespond;

  /// No description provided for @manual.
  ///
  /// In zh, this message translates to:
  /// **'手动'**
  String get manual;

  /// No description provided for @youSelectWhoResponds.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get youSelectWhoResponds;

  /// No description provided for @natural.
  ///
  /// In zh, this message translates to:
  /// **'自然'**
  String get natural;

  /// No description provided for @aiDecidesBasedOnContext.
  ///
  /// In zh, this message translates to:
  /// **'文本'**
  String get aiDecidesBasedOnContext;

  /// No description provided for @membersCount.
  ///
  /// In zh, this message translates to:
  /// **'计数'**
  String membersCount(Object count);

  /// No description provided for @noMembersYet.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get noMembersYet;

  /// No description provided for @talkativenessPercent.
  ///
  /// In zh, this message translates to:
  /// **'健谈度：{percent}%'**
  String talkativenessPercent(Object percent);

  /// No description provided for @triggers.
  ///
  /// In zh, this message translates to:
  /// **'触发词：{words}'**
  String triggers(Object words);

  /// No description provided for @mute.
  ///
  /// In zh, this message translates to:
  /// **'静音'**
  String get mute;

  /// No description provided for @unmute.
  ///
  /// In zh, this message translates to:
  /// **'取消静音'**
  String get unmute;

  /// No description provided for @memberSettings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get memberSettings;

  /// No description provided for @talkativenessLabel.
  ///
  /// In zh, this message translates to:
  /// **'健谈度：{percent}%'**
  String talkativenessLabel(Object percent);

  /// No description provided for @higherValuesMoreLikely.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get higherValuesMoreLikely;

  /// No description provided for @triggerWords.
  ///
  /// In zh, this message translates to:
  /// **'触发词'**
  String get triggerWords;

  /// No description provided for @triggerWordsHint.
  ///
  /// In zh, this message translates to:
  /// **'词1、词2、词3'**
  String get triggerWordsHint;

  /// No description provided for @characterWillRespondWhenTriggered.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get characterWillRespondWhenTriggered;

  /// No description provided for @addMemberToGroup.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get addMemberToGroup;

  /// No description provided for @noMoreCharactersAvailable.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get noMoreCharactersAvailable;

  /// No description provided for @groupSaved.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get groupSaved;

  /// No description provided for @deleteGroupAndChats.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String deleteGroupAndChats(Object name);

  /// No description provided for @startChatAction.
  ///
  /// In zh, this message translates to:
  /// **'聊天'**
  String get startChatAction;

  /// No description provided for @noTagsYet.
  ///
  /// In zh, this message translates to:
  /// **'暂无标签'**
  String get noTagsYet;

  /// No description provided for @createTagsToOrganize.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get createTagsToOrganize;

  /// No description provided for @characterCount.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String characterCount(Object count, Object plural);

  /// No description provided for @deleteTagConfirmation.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String deleteTagConfirmation(Object name);

  /// No description provided for @enterTagName.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get enterTagName;

  /// No description provided for @iconEmoji.
  ///
  /// In zh, this message translates to:
  /// **'图标（表情符号）'**
  String get iconEmoji;

  /// No description provided for @enterEmojiOptional.
  ///
  /// In zh, this message translates to:
  /// **'可选'**
  String get enterEmojiOptional;

  /// No description provided for @pleaseEnterTagName.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get pleaseEnterTagName;

  /// No description provided for @worldInfoLorebooks.
  ///
  /// In zh, this message translates to:
  /// **'世界'**
  String get worldInfoLorebooks;

  /// No description provided for @createLorebook.
  ///
  /// In zh, this message translates to:
  /// **'创建'**
  String get createLorebook;

  /// No description provided for @noLorebooksYet.
  ///
  /// In zh, this message translates to:
  /// **'暂无世界书'**
  String get noLorebooksYet;

  /// No description provided for @lorebooksInjectContext.
  ///
  /// In zh, this message translates to:
  /// **'聊天'**
  String get lorebooksInjectContext;

  /// No description provided for @entriesCount.
  ///
  /// In zh, this message translates to:
  /// **'计数'**
  String entriesCount(Object count);

  /// No description provided for @deleteLorebookConfirmation.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String deleteLorebookConfirmation(Object name);

  /// No description provided for @enterLorebookName.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get enterLorebookName;

  /// No description provided for @optionalDescriptionHint.
  ///
  /// In zh, this message translates to:
  /// **'描述'**
  String get optionalDescriptionHint;

  /// No description provided for @globalScope.
  ///
  /// In zh, this message translates to:
  /// **'全局'**
  String get globalScope;

  /// No description provided for @applyToAllChats.
  ///
  /// In zh, this message translates to:
  /// **'聊天'**
  String get applyToAllChats;

  /// No description provided for @pleaseEnterName2.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get pleaseEnterName2;

  /// No description provided for @noEntriesYet.
  ///
  /// In zh, this message translates to:
  /// **'暂无条目'**
  String get noEntriesYet;

  /// No description provided for @addEntriesWithKeywords.
  ///
  /// In zh, this message translates to:
  /// **'聊天'**
  String get addEntriesWithKeywords;

  /// No description provided for @deleteEntryConfirmation.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String deleteEntryConfirmation(Object keys);

  /// No description provided for @constant.
  ///
  /// In zh, this message translates to:
  /// **'常驻'**
  String get constant;

  /// No description provided for @selective.
  ///
  /// In zh, this message translates to:
  /// **'选择'**
  String get selective;

  /// No description provided for @keywordsCommaSeparated.
  ///
  /// In zh, this message translates to:
  /// **'比率'**
  String get keywordsCommaSeparated;

  /// No description provided for @keywordsHint.
  ///
  /// In zh, this message translates to:
  /// **'向量检索'**
  String get keywordsHint;

  /// No description provided for @entryActivatesWhenKeywordFound.
  ///
  /// In zh, this message translates to:
  /// **'聊天'**
  String get entryActivatesWhenKeywordFound;

  /// No description provided for @secondaryKeysOptional.
  ///
  /// In zh, this message translates to:
  /// **'可选'**
  String get secondaryKeysOptional;

  /// No description provided for @secondaryKeysHint.
  ///
  /// In zh, this message translates to:
  /// **'火、火焰'**
  String get secondaryKeysHint;

  /// No description provided for @bothPrimaryAndSecondaryMustMatch.
  ///
  /// In zh, this message translates to:
  /// **'选择'**
  String get bothPrimaryAndSecondaryMustMatch;

  /// No description provided for @commentOptional.
  ///
  /// In zh, this message translates to:
  /// **'可选'**
  String get commentOptional;

  /// No description provided for @noteForThisEntry.
  ///
  /// In zh, this message translates to:
  /// **'此条目的备注'**
  String get noteForThisEntry;

  /// No description provided for @contentLabel.
  ///
  /// In zh, this message translates to:
  /// **'内容'**
  String get contentLabel;

  /// No description provided for @contextToInjectWhenMatches.
  ///
  /// In zh, this message translates to:
  /// **'文本'**
  String get contextToInjectWhenMatches;

  /// No description provided for @pleaseEnterAtLeastOneKeyword.
  ///
  /// In zh, this message translates to:
  /// **'请至少输入一个关键词'**
  String get pleaseEnterAtLeastOneKeyword;

  /// No description provided for @pleaseEnterContent.
  ///
  /// In zh, this message translates to:
  /// **'内容'**
  String get pleaseEnterContent;

  /// No description provided for @anthropic.
  ///
  /// In zh, this message translates to:
  /// **'Anthropic'**
  String get anthropic;

  /// No description provided for @cohere.
  ///
  /// In zh, this message translates to:
  /// **'Cohere'**
  String get cohere;

  /// No description provided for @customProvider.
  ///
  /// In zh, this message translates to:
  /// **'自定义'**
  String get customProvider;

  /// No description provided for @apiEndpointHint.
  ///
  /// In zh, this message translates to:
  /// **'https://api.example.com/v1'**
  String get apiEndpointHint;

  /// No description provided for @apiKeyHint.
  ///
  /// In zh, this message translates to:
  /// **'sk-...'**
  String get apiKeyHint;

  /// No description provided for @temperatureValue.
  ///
  /// In zh, this message translates to:
  /// **'{value}'**
  String temperatureValue(Object value);

  /// No description provided for @maxTokensValue.
  ///
  /// In zh, this message translates to:
  /// **'{value}'**
  String maxTokensValue(Object value);

  /// No description provided for @topPValue.
  ///
  /// In zh, this message translates to:
  /// **'{value}'**
  String topPValue(Object value);

  /// No description provided for @frequencyPenaltyValue.
  ///
  /// In zh, this message translates to:
  /// **'{value}'**
  String frequencyPenaltyValue(Object value);

  /// No description provided for @presencePenaltyValue.
  ///
  /// In zh, this message translates to:
  /// **'{value}'**
  String presencePenaltyValue(Object value);

  /// No description provided for @streamResponse.
  ///
  /// In zh, this message translates to:
  /// **'流式响应'**
  String get streamResponse;

  /// No description provided for @streamTokensAsGenerated.
  ///
  /// In zh, this message translates to:
  /// **'令牌'**
  String get streamTokensAsGenerated;

  /// No description provided for @useSystemPrompt.
  ///
  /// In zh, this message translates to:
  /// **'提示'**
  String get useSystemPrompt;

  /// No description provided for @includeSystemInstructions.
  ///
  /// In zh, this message translates to:
  /// **'系统'**
  String get includeSystemInstructions;

  /// No description provided for @configurationSavedSuccessfully.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get configurationSavedSuccessfully;

  /// No description provided for @errorSavingConfiguration.
  ///
  /// In zh, this message translates to:
  /// **'错误'**
  String get errorSavingConfiguration;

  /// No description provided for @copyAll.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get copyAll;

  /// No description provided for @showFavoritesOnly.
  ///
  /// In zh, this message translates to:
  /// **'显示'**
  String get showFavoritesOnly;

  /// No description provided for @sortBy.
  ///
  /// In zh, this message translates to:
  /// **'排序方式'**
  String get sortBy;

  /// No description provided for @filterByTags.
  ///
  /// In zh, this message translates to:
  /// **'按标签筛选'**
  String get filterByTags;

  /// No description provided for @favorites.
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get favorites;

  /// No description provided for @manage.
  ///
  /// In zh, this message translates to:
  /// **'管理'**
  String get manage;

  /// No description provided for @noTagsCreatedYet.
  ///
  /// In zh, this message translates to:
  /// **'创建'**
  String get noTagsCreatedYet;

  /// No description provided for @createTags.
  ///
  /// In zh, this message translates to:
  /// **'创建'**
  String get createTags;

  /// No description provided for @charactersCount.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String charactersCount(num count);

  /// No description provided for @characterTagsLegacy.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get characterTagsLegacy;

  /// No description provided for @done.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get done;

  /// No description provided for @applyFiltersSelected.
  ///
  /// In zh, this message translates to:
  /// **'应用'**
  String applyFiltersSelected(Object count);

  /// No description provided for @enterPresetName.
  ///
  /// In zh, this message translates to:
  /// **'预设'**
  String get enterPresetName;

  /// No description provided for @deleteScript.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get deleteScript;

  /// No description provided for @aiConfig.
  ///
  /// In zh, this message translates to:
  /// **'配置'**
  String get aiConfig;

  /// No description provided for @authorsNoteDescription.
  ///
  /// In zh, this message translates to:
  /// **'文本'**
  String get authorsNoteDescription;

  /// No description provided for @enableAuthorsNote.
  ///
  /// In zh, this message translates to:
  /// **'启用'**
  String get enableAuthorsNote;

  /// No description provided for @injectNoteIntoContext.
  ///
  /// In zh, this message translates to:
  /// **'文本'**
  String get injectNoteIntoContext;

  /// No description provided for @injectionDepth.
  ///
  /// In zh, this message translates to:
  /// **'注入深度'**
  String get injectionDepth;

  /// No description provided for @messagesFromEndWhereInserted.
  ///
  /// In zh, this message translates to:
  /// **'消息'**
  String get messagesFromEndWhereInserted;

  /// No description provided for @noteContent.
  ///
  /// In zh, this message translates to:
  /// **'内容'**
  String get noteContent;

  /// No description provided for @authorsNoteHint.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get authorsNoteHint;

  /// No description provided for @enterNameForCheckpoint.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get enterNameForCheckpoint;

  /// No description provided for @addDescription.
  ///
  /// In zh, this message translates to:
  /// **'描述'**
  String get addDescription;

  /// No description provided for @createCheckpointAtMessage.
  ///
  /// In zh, this message translates to:
  /// **'消息'**
  String createCheckpointAtMessage(Object index);

  /// No description provided for @longPressMessageToBookmark.
  ///
  /// In zh, this message translates to:
  /// **'消息'**
  String get longPressMessageToBookmark;

  /// No description provided for @branchFromBookmark.
  ///
  /// In zh, this message translates to:
  /// **'从书签分支'**
  String get branchFromBookmark;

  /// No description provided for @branchFromBookmarkWarning.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String branchFromBookmarkWarning(Object name);

  /// No description provided for @branch.
  ///
  /// In zh, this message translates to:
  /// **'分支'**
  String get branch;

  /// No description provided for @branchedFrom.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String branchedFrom(Object name);

  /// No description provided for @deleteBookmarkConfirmation.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String deleteBookmarkConfirmation(Object name);

  /// No description provided for @messageIndexAndDate.
  ///
  /// In zh, this message translates to:
  /// **'消息'**
  String messageIndexAndDate(Object date, Object index);

  /// No description provided for @branchFromHere.
  ///
  /// In zh, this message translates to:
  /// **'从此处分支'**
  String get branchFromHere;

  /// No description provided for @previewBookmark.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String previewBookmark(Object name);

  /// No description provided for @messageNotFoundInChat.
  ///
  /// In zh, this message translates to:
  /// **'聊天'**
  String get messageNotFoundInChat;

  /// No description provided for @you.
  ///
  /// In zh, this message translates to:
  /// **'你'**
  String get you;

  /// No description provided for @assistant.
  ///
  /// In zh, this message translates to:
  /// **'助手'**
  String get assistant;

  /// No description provided for @reasoningCopiedToClipboard.
  ///
  /// In zh, this message translates to:
  /// **'推理内容已复制到剪贴板'**
  String get reasoningCopiedToClipboard;

  /// No description provided for @charsCount.
  ///
  /// In zh, this message translates to:
  /// **'计数'**
  String charsCount(Object count);

  /// No description provided for @copyReasoning.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get copyReasoning;

  /// No description provided for @commands.
  ///
  /// In zh, this message translates to:
  /// **'命令'**
  String get commands;

  /// No description provided for @aliasesLabel.
  ///
  /// In zh, this message translates to:
  /// **'别名：{aliases}'**
  String aliasesLabel(Object aliases);

  /// No description provided for @noSpritesAddedYet.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get noSpritesAddedYet;

  /// No description provided for @errorLoadingSprites.
  ///
  /// In zh, this message translates to:
  /// **'加载'**
  String get errorLoadingSprites;

  /// No description provided for @insertionPosition.
  ///
  /// In zh, this message translates to:
  /// **'位置'**
  String get insertionPosition;

  /// No description provided for @beforeCharacterDefinition.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get beforeCharacterDefinition;

  /// No description provided for @afterCharacterDefinition.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get afterCharacterDefinition;

  /// No description provided for @beforeExampleMessages.
  ///
  /// In zh, this message translates to:
  /// **'消息'**
  String get beforeExampleMessages;

  /// No description provided for @afterExampleMessages.
  ///
  /// In zh, this message translates to:
  /// **'消息'**
  String get afterExampleMessages;

  /// No description provided for @beforeAuthorNote.
  ///
  /// In zh, this message translates to:
  /// **'作者注释之前'**
  String get beforeAuthorNote;

  /// No description provided for @afterAuthorNote.
  ///
  /// In zh, this message translates to:
  /// **'作者注释之后'**
  String get afterAuthorNote;

  /// No description provided for @atDepth.
  ///
  /// In zh, this message translates to:
  /// **'深度'**
  String get atDepth;

  /// No description provided for @beforeSystemPrompt.
  ///
  /// In zh, this message translates to:
  /// **'提示'**
  String get beforeSystemPrompt;

  /// No description provided for @afterSystemPrompt.
  ///
  /// In zh, this message translates to:
  /// **'提示'**
  String get afterSystemPrompt;

  /// No description provided for @insertionOrder.
  ///
  /// In zh, this message translates to:
  /// **'插入顺序'**
  String get insertionOrder;

  /// No description provided for @lowerOrderInsertsFirst.
  ///
  /// In zh, this message translates to:
  /// **'数值越小越先插入'**
  String get lowerOrderInsertsFirst;

  /// No description provided for @alwaysIncludeInPrompt.
  ///
  /// In zh, this message translates to:
  /// **'常驻'**
  String get alwaysIncludeInPrompt;

  /// No description provided for @requiresSecondaryKey.
  ///
  /// In zh, this message translates to:
  /// **'需次关键词'**
  String get requiresSecondaryKey;

  /// No description provided for @bubbleOpacity.
  ///
  /// In zh, this message translates to:
  /// **'透明度'**
  String get bubbleOpacity;

  /// No description provided for @bubbleOpacityHelp.
  ///
  /// In zh, this message translates to:
  /// **'消息'**
  String get bubbleOpacityHelp;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['ar', 'de', 'en', 'es', 'fr', 'hi', 'id', 'it', 'ja', 'ko', 'ms', 'nl', 'pl', 'pt', 'ru', 'th', 'tr', 'vi', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {

  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'zh': {
  switch (locale.countryCode) {
    case 'TW': return AppLocalizationsZhTw();
   }
  break;
   }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar': return AppLocalizationsAr();
    case 'de': return AppLocalizationsDe();
    case 'en': return AppLocalizationsEn();
    case 'es': return AppLocalizationsEs();
    case 'fr': return AppLocalizationsFr();
    case 'hi': return AppLocalizationsHi();
    case 'id': return AppLocalizationsId();
    case 'it': return AppLocalizationsIt();
    case 'ja': return AppLocalizationsJa();
    case 'ko': return AppLocalizationsKo();
    case 'ms': return AppLocalizationsMs();
    case 'nl': return AppLocalizationsNl();
    case 'pl': return AppLocalizationsPl();
    case 'pt': return AppLocalizationsPt();
    case 'ru': return AppLocalizationsRu();
    case 'th': return AppLocalizationsTh();
    case 'tr': return AppLocalizationsTr();
    case 'vi': return AppLocalizationsVi();
    case 'zh': return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
