import 'dart:convert';

enum ProviderType { openai, anthropic, gemini, deepseek, kimi, glm, custom }

class AiProviderModel {
  final String id;
  final String name;
  final ProviderType type;
  final String apiKey;
  final String baseUrl;
  final List<String> models;
  final String defaultDialogueModel;
  final String defaultNamingModel;
  final bool isEnabled;
  final List<String> enabledModels;
  final String? notes;

  AiProviderModel({
    required this.id,
    required this.name,
    required this.type,
    this.apiKey = '',
    this.baseUrl = '',
    this.models = const [],
    this.defaultDialogueModel = '',
    this.defaultNamingModel = '',
    this.isEnabled = true,
    this.enabledModels = const [],
    this.notes,
  });

  AiProviderModel copyWith({
    String? id,
    String? name,
    ProviderType? type,
    String? apiKey,
    String? baseUrl,
    List<String>? models,
    String? defaultDialogueModel,
    String? defaultNamingModel,
    bool? isEnabled,
    List<String>? enabledModels,
    String? notes,
  }) {
    return AiProviderModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      models: models ?? this.models,
      defaultDialogueModel: defaultDialogueModel ?? this.defaultDialogueModel,
      defaultNamingModel: defaultNamingModel ?? this.defaultNamingModel,
      isEnabled: isEnabled ?? this.isEnabled,
      enabledModels: enabledModels ?? this.enabledModels,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'apiKey': apiKey,
      'baseUrl': baseUrl,
      'models': models,
      'defaultDialogueModel': defaultDialogueModel,
      'defaultNamingModel': defaultNamingModel,
      'isEnabled': isEnabled,
      'enabledModels': enabledModels,
      'notes': notes,
    };
  }

  factory AiProviderModel.fromMap(Map<String, dynamic> map) {
    return AiProviderModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      type: ProviderType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => ProviderType.custom,
      ),
      apiKey: map['apiKey'] ?? '',
      baseUrl: map['baseUrl'] ?? '',
      models: List<String>.from(map['models'] ?? []),
      defaultDialogueModel:
          map['defaultDialogueModel'] ?? map['defaultModel'] ?? '',
      defaultNamingModel:
          map['defaultNamingModel'] ?? map['defaultModel'] ?? '',
      isEnabled: map['isEnabled'] ?? true,
      enabledModels: List<String>.from(map['enabledModels'] ?? []),
      notes: map['notes'],
    );
  }

  String toJson() => json.encode(toMap());

  factory AiProviderModel.fromJson(String source) =>
      AiProviderModel.fromMap(json.decode(source));
}
