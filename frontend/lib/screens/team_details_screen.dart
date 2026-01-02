import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_dimensions.dart';
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
            Text(
              team.title,
              style: AppTextStyles.h1,
            ),
            const SizedBox(height: AppDimensions.paddingMedium),
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
                      title: Text(researcher.fullName, style: AppTextStyles.body),
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

