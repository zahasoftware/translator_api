# Translator App

Cross‑platform (Flutter) translation UI with pluggable backends. First backend: local Ollama LLM used as a translation engine via prompt engineering.

## Features (current)
* Text translation with selectable source (or auto) and target languages.
* Persistent settings for Ollama base URL and model name.
* Simple, responsive UI for desktop & mobile.
* Abstraction layer (`TranslationService`) to add more providers later (e.g. DeepL, OpenAI, Gemini).

## Planned / Easy Extensions
* Streaming translation output.
* Model auto‑detection & caching model list.
* Multi‑segment / document translation.
* Offline queue & history.
* Glossary / custom dictionary.

## Run the App
Ensure you have Flutter installed.

```
flutter pub get
flutter run -d windows   # or another device id
```

## Using Ollama
1. Install Ollama: https://ollama.com
2. Start Ollama server (usually auto, default base URL http://localhost:11434).
3. Pull a model suited for translation (examples):
	 ```
	 ollama pull llama3
	 ollama pull mistral
	 ```
4. In the app Settings set Base URL (if different) and the model name (e.g. `llama3`).
5. Translate.

## Add Another Provider
Implement `TranslationService` and register via a provider/factory (future: dynamic selection UI).

## Code Structure
```
lib/
	core/api_client.dart
	features/translation/
		translation_types.dart
		translation_service.dart
		translation_provider.dart
		ollama_translation_service.dart
	main.dart
```

## License
Private / Unlicensed (adjust as needed).
