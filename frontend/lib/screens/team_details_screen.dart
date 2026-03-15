import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/team_service.dart';
import '../services/researcher_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_dimensions.dart';
import '../utils/clipboard_helper.dart';
import 'researcher_profile_screen.dart';

class TeamDetailsScreen extends StatefulWidget {
  final Team team;
  final bool isEmbedded;
  final Function(Team)? onTeamUpdated;

  const TeamDetailsScreen({
    super.key,
    required this.team,
    this.isEmbedded = false,
    this.onTeamUpdated,
  });

  @override
  State<TeamDetailsScreen> createState() => _TeamDetailsScreenState();
}

class _TeamDetailsScreenState extends State<TeamDetailsScreen> {
  final _teamService = TeamService();
  final _researcherService = ResearcherService();
  final _formKey = GlobalKey<FormState>();

  late Team _team;
  bool _isLoading = false;
  bool _isEditing = false;

  late TextEditingController _titleController;
  List<Researcher> _allResearchers = [];
  List<int> _selectedResearcherIds = [];
  int? _selectedLeaderId;
  bool _isLoadingResearchers = false;

  @override
  void initState() {
    super.initState();
    _team = widget.team;
    _titleController = TextEditingController();
    _initControllers();
  }

  void _initControllers() {
    _titleController.text = _team.title;
    _selectedResearcherIds = _team.researchers?.map((r) => r.id!).toList() ?? [];
    _selectedLeaderId = _team.leaderId;
  }

  @override
  void dispose() {
    _titleController.dispose();
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

  Future<void> _saveTeam() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final teamToUpdate = Team(
          id: _team.id,
          title: _titleController.text,
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

  @override
  Widget build(BuildContext context) {
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
                if (widget.isEmbedded) ...[
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
              _buildLeaderCard(),
            const SizedBox(height: AppDimensions.paddingLarge),
            const Text('Участники проекта:', style: AppTextStyles.h2),
            const SizedBox(height: AppDimensions.paddingMedium),
            if (_isEditing)
              _isLoadingResearchers
                  ? const Center(child: CircularProgressIndicator())
                  : _buildResearchersSelection()
            else
              _buildResearchersList(),
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

  Widget _buildLeaderCard() {
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
              builder: (context) => ResearcherProfileScreen(researcher: _team.leader!),
            ),
          );
        },
      ),
    );
  }

  Widget _buildResearchersList() {
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
                  builder: (context) => ResearcherProfileScreen(researcher: researcher),
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
}
