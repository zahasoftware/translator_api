# Translator App

Cross‑platform (Flutter) translation UI with pluggable backends. Backends: local Ollama LLM (prompt engineered) and Azure Cognitive Services Translator.

## Features (current)
* Text translation with selectable source (or auto) and target languages.
* Persistent settings for provider configuration (Ollama base/model or Azure endpoint/key/region).
* Simple, responsive UI for desktop & mobile + history + theme switching.
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

## Using Azure Translator
1. Create a Translator resource in Azure Portal.
2. Copy Endpoint (e.g. https://YOUR_RESOURCE.cognitiveservices.azure.com), Key, and Region (often the region name or "global").
3. Open Settings -> choose Provider: Azure Translator.
4. Enter the values and Save.
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
