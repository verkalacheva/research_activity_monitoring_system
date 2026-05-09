package testdb

import (
	"database/sql"
	"testing"
)

// InsertSecondTeamWithDev добавляет второго исследователя, команду и dev-метрики (без достижений).
func InsertSecondTeamWithDev(t *testing.T, db *sql.DB, deatID int64) (researcherID, teamID int64) {
	t.Helper()
	if err := db.QueryRow(`INSERT INTO researchers (name, surname, second_name, degree_level, created_at, updated_at)
		VALUES ('Пётр', 'Петров', '', 'д.т.н.', NOW(), NOW()) RETURNING id`).Scan(&researcherID); err != nil {
		t.Fatalf("researcher2: %v", err)
	}
	if err := db.QueryRow(`INSERT INTO teams (title, leader_id, created_at, updated_at)
		VALUES ('Команда Б', $1, NOW(), NOW()) RETURNING id`, researcherID).Scan(&teamID); err != nil {
		t.Fatalf("team2: %v", err)
	}
	if _, err := db.Exec(`INSERT INTO researchers_teams (researcher_id, team_id, created_at, updated_at)
		VALUES ($1, $2, NOW(), NOW())`, researcherID, teamID); err != nil {
		t.Fatalf("researchers_teams2: %v", err)
	}
	InsertDevTeamExtras(t, db, teamID, researcherID, deatID, "readme_team_b")
	return researcherID, teamID
}

// InsertAchievementGraph создаёт цепочку справочников + исследователь + команда + достижение.
func InsertAchievementGraph(t *testing.T, db *sql.DB) (researcherID, teamID, achievementID int64) {
	t.Helper()
	var pid, resid, sid, tid int64
	if err := db.QueryRow(`INSERT INTO achievement_participations (title, points, created_at, updated_at)
		VALUES ('Single', 1, NOW(), NOW()) RETURNING id`).Scan(&pid); err != nil {
		t.Fatalf("participation: %v", err)
	}
	if err := db.QueryRow(`INSERT INTO achievement_results (title, points, created_at, updated_at)
		VALUES ('Win', 1, NOW(), NOW()) RETURNING id`).Scan(&resid); err != nil {
		t.Fatalf("result: %v", err)
	}
	if err := db.QueryRow(`INSERT INTO achievement_statuses (title, points, created_at, updated_at)
		VALUES ('ВАК', 1, NOW(), NOW()) RETURNING id`).Scan(&sid); err != nil {
		t.Fatalf("status: %v", err)
	}
	if err := db.QueryRow(`INSERT INTO achievement_types (title, points, created_at, updated_at)
		VALUES ('Статья ВАК', 1, NOW(), NOW()) RETURNING id`).Scan(&tid); err != nil {
		t.Fatalf("type: %v", err)
	}

	if err := db.QueryRow(`INSERT INTO researchers (name, surname, second_name, degree_level, created_at, updated_at)
		VALUES ('Иван', 'Иванов', '', 'к.т.н.', NOW(), NOW()) RETURNING id`).Scan(&researcherID); err != nil {
		t.Fatalf("researcher: %v", err)
	}

	if err := db.QueryRow(`INSERT INTO teams (title, leader_id, created_at, updated_at)
		VALUES ('Команда А', $1, NOW(), NOW()) RETURNING id`, researcherID).Scan(&teamID); err != nil {
		t.Fatalf("team: %v", err)
	}

	if _, err := db.Exec(`INSERT INTO researchers_teams (researcher_id, team_id, created_at, updated_at)
		VALUES ($1, $2, NOW(), NOW())`, researcherID, teamID); err != nil {
		t.Fatalf("researchers_teams: %v", err)
	}

	if err := db.QueryRow(`INSERT INTO achievements (
			achievement_type_id, achievement_status_id, achievement_result_id, achievement_participation_id,
			points, created_at, updated_at, submission_date)
		VALUES ($1,$2,$3,$4, 5.0, NOW(), NOW(), '2024-06-15'::timestamp)
		RETURNING id`, tid, sid, resid, pid).Scan(&achievementID); err != nil {
		t.Fatalf("achievement: %v", err)
	}

	if _, err := db.Exec(`INSERT INTO researcher_achievements (researcher_id, achievement_id, created_at, updated_at)
		VALUES ($1,$2,NOW(),NOW())`, researcherID, achievementID); err != nil {
		t.Fatalf("researcher_achievements: %v", err)
	}
	return researcherID, teamID, achievementID
}

// InsertDevTeamExtras добавляет критерии и активности для dev_teams / dev_researchers.
// checkKey должен быть уникален среди dev_project_criteria (уникальный индекс в БД).
func InsertDevTeamExtras(t *testing.T, db *sql.DB, teamID, researcherID, deatID int64, checkKey string) {
	t.Helper()
	var dpcID int64
	if err := db.QueryRow(`INSERT INTO dev_project_criteria (title, points, created_at, updated_at, check_key)
		VALUES ('README', 10, NOW(), NOW(), $1) RETURNING id`, checkKey).Scan(&dpcID); err != nil {
		t.Fatalf("dpc: %v", err)
	}
	if _, err := db.Exec(`INSERT INTO team_dev_criteria (team_id, dev_project_criterion_id, created_at, updated_at)
		VALUES ($1,$2,NOW(),NOW())`, teamID, dpcID); err != nil {
		t.Fatalf("tdc: %v", err)
	}
	if _, err := db.Exec(`INSERT INTO researcher_dev_activities (researcher_id, team_id, dev_employee_activity_type_id, count, created_at, updated_at, date)
		VALUES ($1,$2,$3, 2, NOW(), NOW(), '2024-06-01')`, researcherID, teamID, deatID); err != nil {
		t.Fatalf("rda: %v", err)
	}
}

// InsertActivityType возвращает id типа активности.
func InsertActivityType(t *testing.T, db *sql.DB, title, checkKey string) int64 {
	t.Helper()
	var id int64
	if err := db.QueryRow(`INSERT INTO dev_employee_activity_types (title, points, created_at, updated_at, check_key)
		VALUES ($1, 2.5, NOW(), NOW(), $2) RETURNING id`, title, checkKey).Scan(&id); err != nil {
		t.Fatalf("deat: %v", err)
	}
	return id
}
