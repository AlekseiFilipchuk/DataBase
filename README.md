# ЛР №2 — «Образования.нет»

## Быстрый запуск

Текущая папка проекта:

```bash
cd "/mnt/c/Users/NAVIGATOR/OneDrive/Desktop/коды/DataBase"
```

### 1. Запустить PostgreSQL

```bash
docker compose up -d --wait
```

Проверить контейнер:

```bash
docker compose ps
```

Должно быть состояние `Healthy` или `Up`.

---

## 2. Создать схему БД

> Выполнять только при создании базы с нуля. Если миграции уже применялись, повторно их не запускайте.

### Миграция 001

```bash
docker compose exec -T postgres psql -U postgres -d education_lab2 < migrations/001_initial_schema.sql
```

### Миграция 002

```bash
docker compose exec -T postgres psql -U postgres -d education_lab2 < migrations/002_course_prerequisites.sql
```

---

## 3. Загрузить тестовые данные

```bash
docker compose exec -T postgres psql -U postgres -d education_lab2 < data/seed.sql
```

---

## 4. Проверить таблицы

Подключиться к PostgreSQL:

```bash
docker compose exec postgres psql -U postgres -d education_lab2
```

Внутри `psql`:

```sql
\dt
```

Показать структуру таблиц:

```sql
\d users
\d courses
\d enrollments
\d submissions
\d course_prerequisites
```

Выйти:

```sql
\q
```

---

## 5. Посмотреть тестовые данные

### Пользователи

```bash
docker compose exec postgres psql -U postgres -d education_lab2 -c "SELECT * FROM users;"
```

### Курсы

```bash
docker compose exec postgres psql -U postgres -d education_lab2 -c "SELECT * FROM courses;"
```

### Записи на курсы

```bash
docker compose exec postgres psql -U postgres -d education_lab2 -c "SELECT * FROM enrollments;"
```

### Пререквизиты курсов

```bash
docker compose exec postgres psql -U postgres -d education_lab2 -c "SELECT c.title AS course, p.title AS prerequisite FROM course_prerequisites cp JOIN courses c ON c.id = cp.course_id JOIN courses p ON p.id = cp.prerequisite_course_id;"
```

---

## 6. Запустить сценарии жизненного цикла

```bash
docker compose exec -T postgres psql -U postgres -d education_lab2 < scenarios/lifecycle.sql
```

Сценарий демонстрирует жизненные циклы основных сущностей: курс, запись на курс, сдача задания и попытка теста.

---

## 7. Проверить ограничения целостности

```bash
docker compose exec -T postgres psql -U postgres -d education_lab2 < tests/negative_constraints.sql
```

Ожидаемый результат:

```text
PASS 1: UNIQUE users.email
PASS 2: NOT NULL users.full_name
PASS 3: CHECK courses.status
PASS 4: CHECK modules.position
PASS 5: FOREIGN KEY user_roles.user_id
PASS 6: UNIQUE enrollments(user_id, course_id)
PASS 7: answer scope is protected
PASS 8: prerequisite completion is required for enrollment
PASS 9: self-prerequisite is rejected
PASS 10: prerequisite cycle is rejected
```

---

# Полная автоматическая проверка

Это главная команда для проверки всей лабораторной:

```bash
./scripts/test_all.sh
```

Если права на запуск ещё не выданы:

```bash
chmod +x scripts/test_all.sh
./scripts/test_all.sh
```

Скрипт автоматически проверяет:

```text
чистую установку
    ↓
migration 001
    ↓
migration 002
    ↓
seed
    ↓
негативные тесты
```

а затем:

```text
БД старой версии
    ↓
migration 001
    ↓
старые данные
    ↓
migration 002
    ↓
проверка сохранности данных
    ↓
проверка новой функциональности
```

Успешное завершение:

```text
ALL MIGRATION TESTS PASSED
```

---

# Команды для демонстрации преподавателю

## 1. Запуск БД

```bash
docker compose up -d --wait
```

## 2. Показать контейнер

```bash
docker compose ps
```

## 3. Показать таблицы

```bash
docker compose exec postgres psql -U postgres -d education_lab2 -c "\dt"
```

## 4. Показать структуру `courses`

```bash
docker compose exec postgres psql -U postgres -d education_lab2 -c "\d courses"
```

## 5. Показать тестовые курсы

```bash
docker compose exec postgres psql -U postgres -d education_lab2 -c "SELECT id, title, status FROM courses;"
```

## 6. Показать записи на курсы

```bash
docker compose exec postgres psql -U postgres -d education_lab2 -c "SELECT * FROM enrollments;"
```

## 7. Показать пререквизиты

```bash
docker compose exec postgres psql -U postgres -d education_lab2 -c "SELECT c.title AS course, p.title AS prerequisite FROM course_prerequisites cp JOIN courses c ON c.id = cp.course_id JOIN courses p ON p.id = cp.prerequisite_course_id;"
```

## 8. Запустить негативные проверки

```bash
docker compose exec -T postgres psql -U postgres -d education_lab2 < tests/negative_constraints.sql
```

## 9. Показать автоматическую проверку миграций

```bash
./scripts/test_all.sh
```

---

# Если нужно полностью начать заново

> ВНИМАНИЕ: `down -v` удаляет данные PostgreSQL из Docker volume.

Остановить и удалить контейнер вместе с данными:

```bash
docker compose down -v
```

Снова запустить:

```bash
docker compose up -d --wait
```

После этого заново применить:

```bash
docker compose exec -T postgres psql -U postgres -d education_lab2 < migrations/001_initial_schema.sql
docker compose exec -T postgres psql -U postgres -d education_lab2 < migrations/002_course_prerequisites.sql
docker compose exec -T postgres psql -U postgres -d education_lab2 < data/seed.sql
```

---

# Быстрый набор команд

Если всё уже настроено и нужно просто быстро проверить работу:

```bash
cd "/mnt/c/Users/NAVIGATOR/OneDrive/Desktop/коды/DataBase"

docker compose up -d --wait

docker compose ps

docker compose exec postgres psql -U postgres -d education_lab2 -c "\dt"

docker compose exec postgres psql -U postgres -d education_lab2 -c "SELECT id, title, status FROM courses;"

docker compose exec -T postgres psql -U postgres -d education_lab2 < tests/negative_constraints.sql

./scripts/test_all.sh
```

Главный признак успешной автоматической проверки:

```text
ALL MIGRATION TESTS PASSED
```
