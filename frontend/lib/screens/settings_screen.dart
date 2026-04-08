import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_dimensions.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _service = SettingsService();
  bool _isLoading = true;
  bool _isSaving = false;

  // GitHub
  final _githubTokenCtrl = TextEditingController();

  // LLM / Crawler
  final _llmProviderCtrl = TextEditingController();
  final _llmModelCtrl = TextEditingController();
  final _openrouterKeyCtrl = TextEditingController();

  // Search
  final _tavilyKeyCtrl = TextEditingController();

  final Map<String, bool> _obscured = {
    'github_token': true,
    'openrouter_api_key': true,
    'tavily_api_key': true,
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _githubTokenCtrl.dispose();
    _llmProviderCtrl.dispose();
    _llmModelCtrl.dispose();
    _openrouterKeyCtrl.dispose();
    _tavilyKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final s = await _service.getSettings();
      _githubTokenCtrl.text = s.githubToken ?? '';
      _llmProviderCtrl.text = s.llmProvider ?? '';
      _llmModelCtrl.text = s.llmModelName ?? '';
      _openrouterKeyCtrl.text = s.openrouterApiKey ?? '';
      _tavilyKeyCtrl.text = s.tavilyApiKey ?? '';
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки настроек: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      await _service.updateSettings({
        'github_token': _githubTokenCtrl.text.trim().isEmpty ? null : _githubTokenCtrl.text.trim(),
        'llm_provider': _llmProviderCtrl.text.trim().isEmpty ? null : _llmProviderCtrl.text.trim(),
        'llm_model_name': _llmModelCtrl.text.trim().isEmpty ? null : _llmModelCtrl.text.trim(),
        'openrouter_api_key': _openrouterKeyCtrl.text.trim().isEmpty ? null : _openrouterKeyCtrl.text.trim(),
        'tavily_api_key': _tavilyKeyCtrl.text.trim().isEmpty ? null : _tavilyKeyCtrl.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Настройки сохранены'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сохранения: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _toggleObscure(String key) {
    setState(() => _obscured[key] = !(_obscured[key] ?? true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppDimensions.paddingMedium),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else
            TextButton.icon(
              onPressed: _saveSettings,
              icon: const Icon(Icons.save),
              label: const Text('Сохранить'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.paddingLarge),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSection(
                        icon: Icons.code,
                        title: 'GitHub',
                        subtitle: 'Токен для доступа к GitHub API (повышает лимиты запросов)',
                        children: [
                          _buildSecretField(
                            controller: _githubTokenCtrl,
                            label: 'GitHub Personal Access Token',
                            hint: 'ghp_xxxxxxxxxxxxxxxxxxxx',
                            obscureKey: 'github_token',
                            helper: 'Создайте токен на github.com → Settings → Developer settings → Personal access tokens',
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.paddingLarge),
                      _buildSection(
                        icon: Icons.smart_toy,
                        title: 'OpenRouter / Краулер',
                        subtitle: 'Настройки языковой модели для автоматического извлечения достижений',
                        children: [
                          _buildSecretField(
                            controller: _openrouterKeyCtrl,
                            label: 'OpenRouter API Key',
                            hint: 'sk-or-v1-xxxxxxxxxxxxxxxxxxxx',
                            obscureKey: 'openrouter_api_key',
                            helper: 'Получите на openrouter.ai. Можно указать несколько ключей через запятую для ротации.',
                          ),
                          const SizedBox(height: AppDimensions.paddingMedium),
                          _buildTextField(
                            controller: _llmProviderCtrl,
                            label: 'Провайдер (LiteLLM)',
                            hint: 'openrouter',
                            helper: 'Префикс провайдера для LiteLLM. '
                                'Для OpenRouter: openrouter. '
                                'Другие варианты: anthropic, google, openai. '
                                'По умолчанию: openrouter',
                          ),
                          const SizedBox(height: AppDimensions.paddingMedium),
                          _buildTextField(
                            controller: _llmModelCtrl,
                            label: 'Модель',
                            hint: 'google/gemini-2.0-flash-001',
                            helper: 'Название модели без префикса провайдера. '
                                'Итоговая строка: <провайдер>/<модель>. '
                                'По умолчанию: google/gemini-2.0-flash-001',
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.paddingLarge),
                      _buildSection(
                        icon: Icons.search,
                        title: 'Поиск',
                        subtitle: 'API-ключи для поисковых сервисов (используются краулером)',
                        children: [
                          _buildSecretField(
                            controller: _tavilyKeyCtrl,
                            label: 'Tavily API Key',
                            hint: 'tvly-xxxxxxxxxxxxxxxxxxxx',
                            obscureKey: 'tavily_api_key',
                            helper: 'Получите на tavily.com. При отсутствии используется DuckDuckGo',
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.paddingExtraLarge),
                      ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveSettings,
                        icon: const Icon(Icons.save),
                        label: const Text('Сохранить настройки'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 52),
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.paddingLarge),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTextStyles.h3),
                      Text(subtitle, style: AppTextStyles.caption),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingLarge),
            const Divider(height: 1),
            const SizedBox(height: AppDimensions.paddingLarge),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSecretField({
    required TextEditingController controller,
    required String label,
    required String obscureKey,
    String? hint,
    String? helper,
  }) {
    final isObscured = _obscured[obscureKey] ?? true;
    return TextFormField(
      controller: controller,
      obscureText: isObscured,
      style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        helperMaxLines: 3,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: Icon(isObscured ? Icons.visibility : Icons.visibility_off, size: 20),
          onPressed: () => _toggleObscure(obscureKey),
          tooltip: isObscured ? 'Показать' : 'Скрыть',
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? helper,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        helperMaxLines: 3,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
