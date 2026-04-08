module GithubCheckKeys
  # Keys for dev_project_criteria (boolean checks — met/not met)
  CRITERIA_KEYS = [
    # --- File / structure checks ---
    { key: 'has_code',            label: 'Наличие исходного кода',                  category: 'file_check' },
    { key: 'has_readme',          label: 'Наличие README',                           category: 'file_check' },
    { key: 'has_license',         label: 'Наличие лицензии',                         category: 'file_check' },
    { key: 'has_contributing',    label: 'Наличие CONTRIBUTING',                     category: 'file_check' },
    { key: 'has_tests',           label: 'Наличие тестов',                           category: 'file_check' },
    { key: 'has_examples',        label: 'Наличие примеров использования',           category: 'file_check' },
    { key: 'has_cicd',            label: 'Наличие CI/CD (GitHub Actions)',           category: 'file_check' },
    { key: 'has_dir_structure',   label: 'Структурированные директории',             category: 'file_check' },
    { key: 'has_security_policy', label: 'Наличие политики безопасности (SECURITY)', category: 'file_check' },
    { key: 'has_changelog',       label: 'Наличие CHANGELOG',                        category: 'file_check' },
    { key: 'has_dockerfile',      label: 'Наличие Dockerfile',                       category: 'file_check' },
    { key: 'has_dependabot',      label: 'Настроен Dependabot',                      category: 'file_check' },
    { key: 'has_code_of_conduct', label: 'Наличие кодекса поведения',                category: 'file_check' },
    # --- Repository settings ---
    { key: 'has_topics',          label: 'Заданы теги репозитория (Topics)',          category: 'repo_setting' },
    { key: 'has_wiki',            label: 'Включена Wiki',                             category: 'repo_setting' },
    { key: 'has_pages',           label: 'Включены GitHub Pages',                    category: 'repo_setting' },
    { key: 'has_discussions',     label: 'Включены Discussions',                     category: 'repo_setting' },
    { key: 'has_releases',        label: 'Есть публичные релизы',                    category: 'repo_setting' },
    { key: 'has_packages',        label: 'Есть GitHub Packages',                     category: 'repo_setting' },
    # --- Activity checks ---
    { key: 'uses_prs',            label: 'Используются Pull Requests',               category: 'activity_check' },
    { key: 'uses_issues',         label: 'Используются Issues',                      category: 'activity_check' },
    { key: 'has_code_review',     label: 'Проводится Code Review',                   category: 'activity_check' },
    { key: 'multi_contributor',   label: 'Несколько контрибьюторов',                 category: 'activity_check' },
    { key: 'git_conventions',     label: 'Соблюдение git-конвенций',                 category: 'activity_check' },
    # --- Popularity thresholds ---
    { key: 'popular_stars_10',    label: 'Популярный проект (> 10 звёзд)',           category: 'threshold' },
    { key: 'popular_stars_50',    label: 'Популярный проект (> 50 звёзд)',           category: 'threshold' },
    { key: 'popular_stars_100',   label: 'Популярный проект (> 100 звёзд)',          category: 'threshold' },
    { key: 'active_forks_5',      label: 'Активный проект (> 5 форков)',             category: 'threshold' },
    { key: 'active_forks_20',     label: 'Активный проект (> 20 форков)',            category: 'threshold' },
    { key: 'many_watchers_10',    label: 'Много наблюдателей (> 10)',                category: 'threshold' },
    { key: 'many_contributors_3', label: 'Команда контрибьюторов (> 3)',             category: 'threshold' },
    { key: 'many_contributors_10',label: 'Большая команда (> 10 контрибьюторов)',    category: 'threshold' },
    { key: 'many_releases_5',     label: 'Зрелый проект (> 5 релизов)',              category: 'threshold' },
  ].freeze

  # Keys for dev_employee_activity_types (numeric counters)
  ACTIVITY_KEYS = [
    # --- Code activity ---
    { key: 'commits',             label: 'Коммиты',                                  category: 'code' },
    { key: 'pull_requests',       label: 'Открытые Pull Requests',                   category: 'code' },
    { key: 'merged_prs',          label: 'Объединённые Pull Requests',               category: 'code' },
    { key: 'code_reviews',        label: 'Проведение Code Review',                   category: 'code' },
    # --- Issues ---
    { key: 'issues',              label: 'Созданные Issues',                         category: 'issues' },
    { key: 'open_issues',         label: 'Открытые Issues репозитория',              category: 'issues' },
    { key: 'closed_issues',       label: 'Закрытые Issues репозитория',              category: 'issues' },
    # --- Popularity ---
    { key: 'stars',               label: 'Полученные звёзды GitHub',                 category: 'popularity' },
    { key: 'forks',               label: 'Форки репозиториев',                       category: 'popularity' },
    { key: 'watchers',            label: 'Наблюдатели репозитория',                  category: 'popularity' },
    # --- User profile ---
    { key: 'followers',           label: 'Подписчики (Followers)',                   category: 'profile' },
    { key: 'public_repos',        label: 'Публичные репозитории',                    category: 'profile' },
    { key: 'contributions',       label: 'Публичные вклады (Contributions)',         category: 'profile' },
    { key: 'gists',               label: "Публичные Gist'ы",                         category: 'profile' },
    # --- Releases ---
    { key: 'releases',            label: 'Выпущенные релизы',                        category: 'releases' },
    # --- Team / repo info ---
    { key: 'contributor_count',   label: 'Количество контрибьюторов',                category: 'team' },
    { key: 'repo_size',           label: 'Размер репозитория (KB)',                  category: 'info' },
  ].freeze

  ALL_KEYS = (CRITERIA_KEYS + ACTIVITY_KEYS).freeze

  # These check_keys are returned by the GitHub client as current totals (snapshot),
  # not as per-event counts. E.g. "user currently has 150 followers total".
  # They need delta treatment on save to avoid double-counting across syncs.
  # All other keys are event-based (grouped by actual event date) and are idempotent.
  SNAPSHOT_CHECK_KEYS = %w[
    followers public_repos gists
    stars forks watchers open_issues repo_size
    releases contributor_count
  ].freeze

  CATEGORY_LABELS = {
    'file_check'     => 'Файлы и структура',
    'repo_setting'   => 'Настройки репозитория',
    'activity_check' => 'Активность разработки',
    'threshold'      => 'Пороговые значения',
    'code'           => 'Код',
    'issues'         => 'Issues',
    'popularity'     => 'Популярность',
    'profile'        => 'Профиль пользователя',
    'releases'       => 'Релизы',
    'team'           => 'Команда',
    'info'           => 'Информация',
  }.freeze
end
