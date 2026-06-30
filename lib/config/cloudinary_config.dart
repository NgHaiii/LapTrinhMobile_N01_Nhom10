abstract final class CloudinaryConfig {
  CloudinaryConfig._();

  static const String cloudName = 'dtvtryurc';
  static const String uploadPreset = 'provider_documents';

  static String get uploadUrl {
    return 'https://api.cloudinary.com/v1_1/'
        '$cloudName/image/upload';
  }

  static bool get isConfigured {
    return cloudName.trim().isNotEmpty && uploadPreset.trim().isNotEmpty;
  }
}
