import 'package:flutter/material.dart';
import 'package:research_activity_monitoring_system/data/models/models.dart';
import 'package:research_activity_monitoring_system/data/services/team_service.dart';
import 'package:research_activity_monitoring_system/data/services/researcher_service.dart';
import 'package:research_activity_monitoring_system/data/services/dev_project_criterion_service.dart';
import 'package:research_activity_monitoring_system/data/services/sync_notification_service.dart';
import 'package:research_activity_monitoring_system/core/theme/app_colors.dart';
import 'package:research_activity_monitoring_system/core/theme/app_text_styles.dart';
import 'package:research_activity_monitoring_system/core/theme/app_dimensions.dart';
import 'package:research_activity_monitoring_system/core/utils/clipboard_helper.dart';
import 'package:research_activity_monitoring_system/presentation/screens/researcher/researcher_profile_screen.dart';

class TeamDetailsScreen extends StatefulWidget {
  final Team team;
  final bool isEmbedded;
  final bool readOnly;
  final Function(Team)? onTeamUpdated;

  const TeamDetailsScreen({
    super.key,
    required this.team,
    this.isEmbedded = false,
    this.readOnly = false,
    this.onTeamUpdated,
  });

  @override
  State<TeamDetailsScreen> createState() => _TeamDetailsScreenState();
}

class _TeamDetailsScreenState extends State<TeamDetailsScreen> {
  final _teamService = TeamService();
  final _researcherService = ResearcherService();
  final _criterionService = DevProjectCriterionService();
  final _formKey = GlobalKey<FormState>();

  late Team _team;
  bool _isLoading = false;
  bool _isEditing = false;

  late TextEditingController _titleController;
  late TextEditingController _githubRepoController;
  List<Researcher> _allResearchers = [];
  List<int> _selectedResearcherIds = [];
  int? _selectedLeaderId;
  bool _isLoadingResearchers = false;

  List<DevProjectCriterion> _allCriteria = [];
  List<int> _selectedCriterionIds = [];
  bool _isLoadingCriteria = false;
  bool _isSavingCriteria = false;

  @override
  void initState() {
    super.initState();
    _team = widget.team;
    _titleController = TextEditingController();
    _githubRepoController = TextEditingController();
    _initControllers();
  }

  void _initControllers() {
    _titleController.text = _team.title;
    _githubRepoController.text = _team.githubRepoUrl ?? '';
    _selectedResearcherIds = _team.researchers?.map((r) => r.id!).toList() ?? [];
    _selectedLeaderId = _team.leaderId;
    _selectedCriterionIds = _team.devProjectCriteria?.map((c) => c.id!).toList() ?? [];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _githubRepoController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TeamDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.team != widget.team) {
      setState(() {
        _team = widget.team;
        _isEditing = false;
        _initControllers();
      });
    }
  }

  bool _isReadOnly(BuildContext context) {
    return widget.readOnly;
  }

  Future<void> _loadResearchers() async {
    setState(() => _isLoadingResearchers = true);
    try {
      final researchers = await _researcherService.getAll();
      setState(() {
        _allResearchers = researchers;
        _isLoadingResearchers = false;
      });
    } catch (e) {
      setState(() => _isLoadingResearchers = false);
    }
  }

  Future<void> _loadCriteria() async {
    setState(() => _isLoadingCriteria = true);
    try {
      final result = await _criterionService.list(limit: 200);
      setState(() {
        _allCriteria = result.items;
        _isLoadingCriteria = false;
      });
    } catch (e) {
      setState(() => _isLoadingCriteria = false);
    }
  }

  Future<void> _saveCriteria() async {
    setState(() => _isSavingCriteria = true);
    try {
      final updated = await _teamService.updateCriteria(_team.id!, _selectedCriterionIds);
      setState(() {
        _team = updated;
        _isSavingCriteria = false;
      });
      widget.onTeamUpdated?.call(_team);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Критерии сохранены')),
        );
      }
    } catch (e) {
      setState(() => _isSavingCriteria = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сохранения критериев: $e')),
        );
      }
    }
  }

  Future<void> _saveTeam() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final teamToUpdate = Team(
          id: _team.id,
          title: _titleController.text,
          githubRepoUrl: _githubRepoController.text,
          leaderId: _selectedLeaderId,
          researchers: _allResearchers
              .where((r) => _selectedResearcherIds.contains(r.id))
              .toList(),
        );

        final updated = await _teamService.update(_team.id!, teamToUpdate);
        setState(() {
          _team = updated;
          _isEditing = false;
          _isLoading = false;
        });
        widget.onTeamUpdated?.call(_team);
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка сохранения: $e')),
          );
        }
      }
    }
  }

  void _showSyncDialog() {
    SyncNotificationService.instance.enqueue(SyncRequest(
      provider: 'github',
      teamId: _team.id,
      label: 'GitHub — ${_team.title ?? "проект"}',
      onSaved: () async {
        if (!mounted) return;
        final updated = await _teamService.getById(_team.id!);
        if (!mounted) return;
        setState(() {
          _team = updated;
          _initControllers();
        });
        widget.onTeamUpdated?.call(_team);
      },
    ));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Синхронизация GitHub запущена в фоне')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final readOnly = _isReadOnly(context);
    if (readOnly && _isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _isEditing = false);
      });
    }

    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.paddingLarge),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: _isEditing
                      ? TextFormField(
                          controller: _titleController,
                          style: AppTextStyles.h1,
                          decoration: const InputDecoration(
                            labelText: 'Название проекта',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => v?.isEmpty ?? true ? 'Обязательно' : null,
                        )
                      : Text(_team.title, style: AppTextStyles.h1),
                ),
                if (widget.isEmbedded && !readOnly) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(_isEditing ? Icons.close : Icons.edit, color: AppColors.primary),
                    onPressed: () {
                      if (!_isEditing && _allResearchers.isEmpty) {
                        _loadResearchers();
                      }
                      setState(() {
                        if (_isEditing) _initControllers();
                        _isEditing = !_isEditing;
                      });
                    },
                    tooltip: _isEditing ? 'Отмена' : 'Редактировать',
                  ),
                ],
                if (widget.isEmbedded) const SizedBox(width: 40),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingLarge),
            _isEditing
                ? TextFormField(
                    controller: _githubRepoController,
                    decoration: const InputDecoration(
                      labelText: 'GitHub Repository URL',
                      hintText: 'https://github.com/owner/repo',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.code),
                    ),
                  )
                : _buildInfoRow('GitHub Repo:', _team.githubRepoUrl ?? 'Не указан',
                    trailing: _team.githubRepoUrl != null &&
                            _team.githubRepoUrl!.isNotEmpty &&
                            !readOnly
                        ? IconButton(
                            icon: const Icon(Icons.sync, color: AppColors.primary),
                            onPressed: _showSyncDialog,
                            tooltip: 'Синхронизировать данные проекта',
                          )
                        : null),
            const SizedBox(height: AppDimensions.paddingLarge),
            const Text('Руководитель проекта:', style: AppTextStyles.h2),
            const SizedBox(height: AppDimensions.paddingMedium),
            if (_isEditing)
              _isLoadingResearchers
                  ? const Center(child: CircularProgressIndicator())
                  : DropdownButtonFormField<int>(
                      value: _selectedLeaderId,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: _allResearchers.map((r) {
                        return DropdownMenuItem<int>(
                          value: r.id,
                          child: Text(r.fullName),
                        );
                      }).toList(),
                      onChanged: (value) => setState(() => _selectedLeaderId = value),
                    )
            else
              _buildLeaderCard(readOnly),
            const SizedBox(height: AppDimensions.paddingLarge),
            _buildCriteriaSection(readOnly),
            if (!_isEditing && (_team.devCriteriaSum != null || _team.devActivitiesSum != null)) ...[
              const SizedBox(height: AppDimensions.paddingLarge),
              const Text('Оценка проекта (разработка):', style: AppTextStyles.h2),
              const SizedBox(height: AppDimensions.paddingMedium),
              Row(
                children: [
                  Expanded(
                    child: Card(
                      child: ListTile(
                        leading: const Icon(Icons.assessment, color: AppColors.primary),
                        title: Text('Сумма критериев: ${(_team.devCriteriaSum ?? 0).toStringAsFixed(1)}'),
                        subtitle: const Text('Выполненные требования'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Card(
                      child: ListTile(
                        leading: const Icon(Icons.star, color: AppColors.warning),
                        title: Text('Баллы за активность: ${(_team.devActivitiesSum ?? 0).toStringAsFixed(1)}'),
                        subtitle: const Text('Звезды, форки и др.'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppDimensions.paddingLarge),
            const Text('Участники проекта:', style: AppTextStyles.h2),
            const SizedBox(height: AppDimensions.paddingMedium),
            if (_isEditing)
              _isLoadingResearchers
                  ? const Center(child: CircularProgressIndicator())
                  : _buildResearchersSelection()
            else
              _buildResearchersList(readOnly),
            if (_isEditing) ...[
              const SizedBox(height: AppDimensions.paddingExtraLarge),
              Center(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveTeam,
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Сохранить изменения'),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (widget.isEmbedded) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: content,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Детали проекта'),
      ),
      body: content,
    );
  }

  Widget _buildInfoRow(String label, String value, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.paddingSmall),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: AppTextStyles.bodySecondary),
          ),
          Expanded(
            child: Text(value, style: AppTextStyles.body),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildLeaderCard(bool readOnly) {
    if (_team.leader == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(AppDimensions.paddingLarge),
          child: Center(
            child: Text(
              'Руководитель не назначен',
              style: AppTextStyles.bodySecondary,
            ),
          ),
        ),
      );
    }
    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: AppColors.primary,
          child: Icon(Icons.star, color: AppColors.textOnPrimary),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                _team.leader!.fullName,
                style: AppTextStyles.body,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.star, size: 16, color: AppColors.warning),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.copy, size: 20, color: AppColors.inactive),
          onPressed: () => ClipboardHelper.copyToClipboard(context, _team.leader!.fullName),
          tooltip: 'Копировать ФИО',
        ),
        subtitle: Text(
          '${_team.leader!.degreeLevel ?? ''} ${_team.leader!.subjectArea ?? ''}'.trim(),
          style: AppTextStyles.caption,
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ResearcherProfileScreen(
                researcher: _team.leader!,
                readOnly: readOnly,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildResearchersList(bool readOnly) {
    if (_team.researchers == null || _team.researchers!.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(AppDimensions.paddingLarge),
          child: Center(
            child: Text(
              'В этом проекте пока нет участников',
              style: AppTextStyles.bodySecondary,
            ),
          ),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _team.researchers!.length,
      itemBuilder: (context, index) {
        final researcher = _team.researchers![index];
        return Card(
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppColors.background,
              child: Icon(Icons.person, color: AppColors.primary),
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    researcher.fullName,
                    style: AppTextStyles.body,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (researcher.isLeader) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.star, size: 16, color: AppColors.warning),
                ],
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.copy, size: 20, color: AppColors.inactive),
              onPressed: () => ClipboardHelper.copyToClipboard(context, researcher.fullName),
              tooltip: 'Копировать ФИО',
            ),
            subtitle: Text(
              '${researcher.degreeLevel ?? ''} ${researcher.subjectArea ?? ''}'.trim(),
              style: AppTextStyles.caption,
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ResearcherProfileScreen(
                    researcher: researcher,
                    readOnly: readOnly,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildResearchersSelection() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _allResearchers.length,
      itemBuilder: (context, index) {
        final researcher = _allResearchers[index];
        final isSelected = _selectedResearcherIds.contains(researcher.id);
        return CheckboxListTile(
          title: Text(researcher.fullName),
          subtitle: Text(researcher.degreeLevel ?? ''),
          value: isSelected,
          onChanged: (bool? value) {
            setState(() {
              if (value == true) {
                _selectedResearcherIds.add(researcher.id!);
              } else {
                _selectedResearcherIds.remove(researcher.id);
              }
            });
          },
        );
      },
    );
  }

  Widget _buildCriteriaSection(bool readOnly) {
    final metCriteria = _team.devProjectCriteria ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Критерии проекта:', style: AppTextStyles.h2),
            const Spacer(),
            if (!_isEditing && !readOnly)
              TextButton.icon(
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Изменить'),
                onPressed: () async {
                  if (_allCriteria.isEmpty) await _loadCriteria();
                  setState(() {
                    _selectedCriterionIds =
                        metCriteria.map((c) => c.id!).toList();
                  });
                  _showCriteriaEditDialog();
                },
              ),
          ],
        ),
        const SizedBox(height: AppDimensions.paddingMedium),
        if (metCriteria.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingLarge),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline,
                      color: AppColors.inactive, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Критерии не выбраны',
                    style: AppTextStyles.bodySecondary,
                  ),
                ],
              ),
            ),
          )
        else
          ...metCriteria.map((c) => Card(
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.check_circle,
                      color: AppColors.success, size: 20),
                  title: Text(c.title, style: AppTextStyles.body),
                  trailing: c.points != null
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${c.points!.toStringAsFixed(1)} б.',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.primary),
                          ),
                        )
                      : null,
                ),
              )),
      ],
    );
  }

  void _showCriteriaEditDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          if (_isLoadingCriteria) {
            return const AlertDialog(
              content: SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              ),
            );
          }

          final selected = List<int>.from(_selectedCriterionIds);
          double totalPoints = _allCriteria
              .where((c) => selected.contains(c.id))
              .fold(0.0, (sum, c) => sum + (c.points ?? 0));

          return AlertDialog(
            title: const Text('Критерии проекта'),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Выбрано: ${selected.length} · Сумма: ${totalPoints.toStringAsFixed(1)} б.',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 400),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _allCriteria.length,
                      itemBuilder: (_, i) {
                        final c = _allCriteria[i];
                        final isSel = selected.contains(c.id);
                        return CheckboxListTile(
                          dense: true,
                          value: isSel,
                          title: Text(c.title),
                          secondary: c.points != null
                              ? Text(
                                  '${c.points!.toStringAsFixed(1)} б.',
                                  style: AppTextStyles.caption
                                      .copyWith(color: AppColors.primary),
                                )
                              : null,
                          onChanged: (v) {
                            setDialogState(() {
                              if (v == true) {
                                selected.add(c.id!);
                              } else {
                                selected.remove(c.id);
                              }
                            });
                            setState(() => _selectedCriterionIds = selected);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: _isSavingCriteria
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        await _saveCriteria();
                      },
                child: const Text('Сохранить'),
              ),
            ],
          );
        },
      ),
    );
  }
}
