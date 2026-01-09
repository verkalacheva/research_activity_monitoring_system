import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/team_service.dart';
import '../services/researcher_service.dart';
import '../theme/app_dimensions.dart';

class TeamFormScreen extends StatefulWidget {
  final Team? team;

  const TeamFormScreen({super.key, this.team});

  @override
  State<TeamFormScreen> createState() => _TeamFormScreenState();
}

class _TeamFormScreenState extends State<TeamFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final TeamService _service = TeamService();
  final ResearcherService _researcherService = ResearcherService();

  late TextEditingController _titleController;
  List<Researcher> _allResearchers = [];
  List<int> _selectedResearcherIds = [];
  int? _selectedLeaderId;
  bool _isLoadingResearchers = true;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.team?.title ?? '');
    _selectedResearcherIds = widget.team?.researchers?.map((r) => r.id!).toList() ?? [];
    _selectedLeaderId = widget.team?.leaderId;
    _loadResearchers();
  }

  Future<void> _loadResearchers() async {
    try {
      final researchers = await _researcherService.getAll();
      setState(() {
        _allResearchers = researchers;
        _isLoadingResearchers = false;
      });
    } catch (e) {
      setState(() => _isLoadingResearchers = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки сотрудников: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _save() async {
    if (_formKey.currentState!.validate()) {
      final team = Team(
        id: widget.team?.id,
        title: _titleController.text,
        leaderId: _selectedLeaderId,
        researchers: _allResearchers
            .where((r) => _selectedResearcherIds.contains(r.id))
            .toList(),
      );

      try {
        if (widget.team == null) {
          await _service.create(team);
        } else {
          await _service.update(widget.team!.id!, team);
        }
        if (mounted) Navigator.pop(context, true);
      } catch (e) {
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.team == null ? 'Новый проект' : 'Редактирование проекта'),
      ),
      body: _isLoadingResearchers
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.paddingLarge),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: 'Название проекта *'),
                      validator: (value) => value == null || value.isEmpty ? 'Введите название' : null,
                    ),
                    const SizedBox(height: AppDimensions.paddingMedium),
                    DropdownButtonFormField<int>(
                      value: _selectedLeaderId,
                      decoration: const InputDecoration(labelText: 'Руководитель проекта'),
                      items: _allResearchers.map((r) {
                        return DropdownMenuItem<int>(
                          value: r.id,
                          child: Text(r.fullName),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedLeaderId = value);
                      },
                    ),
                    const SizedBox(height: AppDimensions.paddingExtraLarge),
                    const Text('Участники проекта:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: AppDimensions.paddingMedium),
                    ListView.builder(
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
                    ),
                    const SizedBox(height: AppDimensions.paddingExtraLarge),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _save,
                        child: const Text('Сохранить'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

