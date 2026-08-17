/// The list of background templates the user can choose between on the
/// positioning screen. Each must also be listed under `flutter: assets:`
/// in pubspec.yaml.
///
/// To add a new template later:
///   1. Drop the PNG into assets/ (or a subfolder)
///   2. Add its path to pubspec.yaml's assets list
///   3. Add a TemplateOption entry below
class TemplateOption {
  final String assetPath;
  final String name;
  const TemplateOption({required this.assetPath, required this.name});
}

const List<TemplateOption> availableTemplates = [
  TemplateOption(assetPath: 'assets/background_template.png', name: 'Mandala Classic'),
];
