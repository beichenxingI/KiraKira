# KiraKira

⚠️ This project is under active development. Some features may differ from the description.

<p align="center">
  <a href="README.md">简体中文</a> | <a href="README.en.md">English</a>
</p>

A native cross-platform AI chat client for iOS and Android, based on [NativeTavern](https://github.com/Bahamutho/NativeTavern), fully compatible with SillyTavern data formats.

## Screenshots

<p align="center">
  <img src="photo/set.png" width="200" alt="set Interface"/>
  <img src="photo/Character.png" width="200" alt="Character"/>
  <img src="photo/AiConfig.png" width="200" alt="AI Config"/>
</p>

<p align="center">
  <img src="photo/AIPreset.png" width="200" alt="AI Preset"/>
  <img src="photo/PromptManager.png" width="200" alt="Prompt Manager"/>
  <img src="photo/Wordbook.png" width="200" alt="World Info"/>
</p>

| Chat | Character | AI Config |
|:---:|:---:|:---:|
| Real-time streaming chat with message operations | Character cards with avatars and details | Multi-provider LLM configuration |

| AI Preset | Prompt Manager | World Info |
|:---:|:---:|:---:|
| Import SillyTavern presets | Custom prompt ordering | Keyword-based context injection |

## Key Features

### Core Features
- 📱 **Native App** - Built with Flutter for iOS and Android
- 🤖 **Multi-Provider Support** - OpenAI, Claude, OpenRouter, Gemini, Ollama, KoboldCpp
- 📦 **SillyTavern Compatible** - Import/export PNG cards, CharX, JSON formats
- 💬 **Streaming Response** - Real-time SSE streaming support

### Chronicle Super Memory System
An experimental solution for long conversation memory loss and relationship confusion. The system automatically summarizes conversation history, injects content in layers (cold/warm/hot/unarchived zones), and recalls relevant information through vector retrieval and keyword hybrid matching.

- 📝 **Auto Summarization** - Automatic summarization by conversation turns
- 🔍 **Smart Recall** - Vector semantic retrieval + keyword matching
- 📊 **Layered Injection** - Attention weight allocation based on temporal distance
- 🧠 **Entity Tracking** - Track characters, relationships, and emotional changes
- 📈 **Visualization Panel** - Real-time view of summarization progress and status

### Character Management
- 📥 **Import Formats** - PNG V2/V3, CharX (V3 spec), JSON
- 📤 **Export Formats** - PNG V3, CharX with assets, JSON
- ✏️ **Character Editor** - Full character field editing
- 🏷️ **Tag System** - Categorize and filter characters with tags
- 📚 **Embedded Lorebook** - Full CharX lorebook support

### Chat Features
- 💬 **Message Operations** - Edit, delete, regenerate, swipe between alternatives
- 👥 **Group Chat** - Multi-character conversations with 5 response modes
- 🔖 **Bookmarks** - Create checkpoints and branching conversations
- 📝 **Author's Note** - Configurable depth injection
- 🎭 **Personas** - User profile management
- 📄 **Rich Text** - HTML/Markdown rendering

### World Info/Lorebook
- 🌍 **Keyword Matching** - Trigger-based context injection
- 📍 **Multiple Positions** - Before/after system prompt, character definition, example dialogue
- 🔄 **Recursive Support** - Nested keyword scanning
- 📊 **Group Scoring** - Priority-based entry selection

### Prompt Management
- 📋 **Prompt Ordering** - Custom prompt sequence
- 📥 **Preset Import** - Full SillyTavern preset support
- 🎯 **Custom Prompts** - Add custom sections with character support
- 📍 **Depth Injection** - Insert prompts at specific message depths

### Advanced Settings
- 🎛️ **Sampler Control** - Temperature, Top-P, Top-K, Min-P, Typical-P
- 🔁 **Repetition Penalty** - Configurable range
- 🎲 **Mirostat** - Mode, Tau, Eta settings
- ✂️ **Tail Free Sampling** - TFS and Top-A support
- 🛑 **Stop Sequences** - Custom stop tokens

### Chain of Thought Support
- 🧠 **OpenAI o1/o3** - Parse `reasoning_content` field
- 💭 **Claude** - Parse `thinking` blocks
- 🤔 **Gemini 2.0 Flash Thinking** - Parse `thought` field
- 📦 **Collapsible UI** - Expandable reasoning blocks
- ⏳ **Streaming Display** - Real-time reasoning conten

### Text-to-Speech (TTS)
- 🔊 **Multiple Providers** - System TTS, ElevenLabs, Azure
- 🎭 **Character Voices** - Independent configuration per character
- ▶️ **Auto Play** - Automatically read new messages
- 🎚️ **Voice Control** - Speed, pitch, volume adjustment

### Speech-to-Text (STT)
- 🎤 **Voice Input** - Dictate messages with voice
- 🌍 **16 Languages** - Support for major languages
- 🔄 **Multiple Providers** - System STT, Whisper, Azure
- ⚡ **Auto Send** - Auto-send after speaking

### Translation
- 🌐 **30+ Languages** - Translate between major languages
- 🔄 **Multiple Providers** - Google, DeepL, LibreTranslate
- 🔀 **Auto Translate** - Both received and sent messages
- 🔍 **Language Detection** - Auto-detect source language

### Image Generation
- 🎨 **Multiple Providers** - Stable Diffusion, DALL-E, ComfyUI, Automatic1111
- 📐 **Size Presets** - 512x512, 768x768, 1024x1024, etc.
- ⚙️ **Generation Settings** - Steps, CFG scale, sampler selection
- 🚫 **Negative Prompts** - Exclude unwanted elements

### Regex Scripts
- 🔍 **Find/Replace Patterns** - Apply regex to messages
- 📝 **Script Management** - Create, edit, delete, reorder scripts
- 🎯 **Apply Locations** - User input, AI output, slash commands
- 🔄 **Import/Export** - Share scripts in JSON format

### Variable System
- 🌐 **Global Variables** - App-wide persistent storage
- 💬 **Local Variables** - Per-chat variable storage
- 📝 **Variable Macros** - `{{getvar}}`, `{{setvar}}`, `{{incvar}}`, etc.
- 🔢 **Type Support** - Numbers, strings, arrays, objects

### Chat Backup
- 💾 **Auto Backup** - Configurable intervals (hourly, daily, weekly)
- 📁 **Chat Backup** - Individual chat export (JSONL)
- 📦 **Full Backup** - Complete data export (JSON)
- 👁️ **View/Restore** - Browse and restore backups

### Macro System
Supports common macros including:
- `{{user}}`, `{{char}}` - Persona and character names
- `{{time}}`, `{{date}}`, `{{day}}` - Date and time
- `{{random:min:max}}` - Random number generation
- `{{roll:XdY}}` - Dice rolling
- `{{idle_duration}}` - Time since last message

### Slash Commands
- `/continue` - Continue generation
- `/regenerate` - Regenerate last message
- `/swipe` - Navigate swipes
- `/persona` - Switch persona
- `/sys` - Send system message
- `/help` - Show command help

### Other Features
- 🖼️ **Custom Backgrounds** - Set background images per chat
- ⌨️ **Markdown Shortcuts** - ⌘B bold, ⌘I italic, ⌘U underline
- 🔗 **Link Support** - ⌘K quick insert link

## Tech Stack

| Component | Technology |
|-----------|------------|
| UI Framework | Flutter (Dart) |
| State Management | Riverpod |
| Navigation | go_router |
| Database | SQLite (drift) |
| HTTP Client | Dio |

## Getting Started

### Prerequisites
- Flutter SDK >= 3.16.0
- Xcode (for iOS development)
- Android Studio (for Android development)

### Installation

1. Clone the repository
   ```bash
   git clone https://github.com/beichenxingI/KiraKira.git
   cd KiraKira
   ```

2. Install dependencies
   ```bash
   flutter pub get
   ```

3. Run the app
   ```bash
   flutter run
   ```

## SillyTavern Compatibility

### Supported Import Formats

| Format | Description | Status |
|--------|-------------|--------|
| PNG V2 | Character cards with `chara` tEXt chunk | ✅ Supported |
| PNG V3 | Character cards with `ccv3` tEXt chunk | ✅ Supported |
| CharX | ZIP archive with card.json + assets | ✅ Supported |
| JSON | Raw character JSON export | ✅ Supported |
| ST Presets | SillyTavern AI preset JSON | ✅ Supported |

### Supported Export Formats

| Format | Description | Status |
|--------|-------------|--------|
| PNG V3 | Export as PNG with embedded metadata | ✅ Supported |
| CharX | Export with all assets included | ✅ Supported |
| JSON | Raw export for backup | ✅ Supported |

## License

This project is licensed under AGPL-3.0 - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [NativeTavern](https://github.com/Bahamutho/NativeTavern) - This project is based on NativeTavern
- [SillyTavern](https://github.com/SillyTavern/SillyTavern) - Provided reference for feature design
- [Flutter](https://flutter.dev) - Cross-platform UI framework
- [Riverpod](https://riverpod.dev) - State management library

## Issues

Encountered a problem or have suggestions? Feel free to submit on [GitHub Issues](https://github.com/beichenxingI/KiraKira/issues).