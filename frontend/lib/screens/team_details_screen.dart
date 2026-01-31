import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_dimensions.dart';
import '../utils/clipboard_helper.dart';
import 'researcher_profile_screen.dart';

class TeamDetailsScreen extends StatelessWidget {
  final Team team;

  const TeamDetailsScreen({super.key, required this.team});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Детали проекта'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    team.title,
                    style: AppTextStyles.h1,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 24, color: AppColors.inactive),
                  onPressed: () => ClipboardHelper.copyToClipboard(context, team.title),
                  tooltip: 'Копировать название проекта',
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingLarge),
            const Text(
              'Руководитель проекта:',
              style: AppTextStyles.h2,
            ),
            const SizedBox(height: AppDimensions.paddingMedium),
            if (team.leader == null)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(AppDimensions.paddingLarge),
                  child: Center(
                    child: Text(
                      'Руководитель не назначен',
                      style: AppTextStyles.bodySecondary,
                    ),
                  ),
                ),
              )
            else
              Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.primary,
                    child: Icon(Icons.star, color: Colors.white),
                  ),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(
                          team.leader!.fullName,
                          style: AppTextStyles.body,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.star, size: 16, color: Colors.amber),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 20, color: AppColors.inactive),
                        onPressed: () => ClipboardHelper.copyToClipboard(context, team.leader!.fullName),
                        tooltip: 'Копировать ФИО',
                      ),
                    ],
                  ),
                  subtitle: Text(
                    '${team.leader!.degreeLevel ?? ''} ${team.leader!.subjectArea ?? ''}'.trim(),
                    style: AppTextStyles.caption,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ResearcherProfileScreen(researcher: team.leader!),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: AppDimensions.paddingLarge),
            const Text(
              'Участники проекта:',
              style: AppTextStyles.h2,
            ),
            const SizedBox(height: AppDimensions.paddingMedium),
            if (team.researchers == null || team.researchers!.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(AppDimensions.paddingLarge),
                  child: Center(
                    child: Text(
                      'В этом проекте пока нет участников',
                      style: AppTextStyles.bodySecondary,
                    ),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: team.researchers!.length,
                itemBuilder: (context, index) {
                  final researcher = team.researchers![index];
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
                            const Icon(Icons.star, size: 16, color: Colors.amber),
                          ],
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 20, color: AppColors.inactive),
                            onPressed: () => ClipboardHelper.copyToClipboard(context, researcher.fullName),
                            tooltip: 'Копировать ФИО',
                          ),
                        ],
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
              ),
          ],
        ),
      ),
    );
  }
}

