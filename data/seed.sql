BEGIN;

-- Demo-only hashes. Real passwords are never stored as plain text.
INSERT INTO users(email, full_name, password_hash) VALUES
    ('ivan@example.com', 'Иван Петров', '$2b$12$demo_student_hash'),
    ('anna@example.com', 'Анна Смирнова', '$2b$12$demo_teacher_hash'),
    ('olga@example.com', 'Ольга Кузнецова', '$2b$12$demo_teacher_hash'),
    ('admin@example.com', 'Администратор', '$2b$12$demo_admin_hash');

INSERT INTO user_roles(user_id, role_id)
SELECT u.id, r.id
FROM users u
CROSS JOIN roles r
WHERE (u.email = 'anna@example.com' AND r.code = 'teacher')
   OR (u.email = 'olga@example.com' AND r.code = 'teacher')
   OR (u.email = 'admin@example.com' AND r.code = 'admin');

INSERT INTO courses(teacher_id, title, description, status, published_at)
SELECT u.id,
       'Основы PostgreSQL',
       'Основы SQL, таблицы, связи, ограничения и транзакции.',
       'published',
       CURRENT_TIMESTAMP
FROM users u WHERE u.email = 'anna@example.com';

INSERT INTO courses(teacher_id, title, description, status)
SELECT u.id,
       'Продвинутый PostgreSQL',
       'Сложные запросы, индексы и проектирование схем.',
       'draft'
FROM users u WHERE u.email = 'anna@example.com';

INSERT INTO courses(teacher_id, title, description, status, published_at, archived_at)
SELECT u.id,
       'Основы алгоритмов',
       'Базовые алгоритмы и структуры данных.',
       'archived',
       CURRENT_TIMESTAMP - INTERVAL '30 days',
       CURRENT_TIMESTAMP
FROM users u WHERE u.email = 'olga@example.com';

INSERT INTO course_prerequisites(course_id, prerequisite_course_id)
SELECT advanced.id, basics.id
FROM courses advanced
JOIN courses basics
  ON basics.title = 'Основы PostgreSQL'
 AND advanced.title = 'Продвинутый PostgreSQL';

INSERT INTO modules(course_id, title, position)
SELECT c.id, 'SQL и структура БД', 1
FROM courses c WHERE c.title = 'Основы PostgreSQL';

INSERT INTO modules(course_id, title, position)
SELECT c.id, 'Ограничения целостности', 2
FROM courses c WHERE c.title = 'Основы PostgreSQL';

INSERT INTO lessons(module_id, title, position, content_ref)
SELECT m.id, 'SELECT и WHERE', 1, 'mongo:lesson:postgres:select'
FROM modules m
JOIN courses c ON c.id = m.course_id
WHERE c.title = 'Основы PostgreSQL' AND m.position = 1;

INSERT INTO lessons(module_id, title, position, content_ref)
SELECT m.id, 'JOIN и связи', 2, 'mongo:lesson:postgres:join'
FROM modules m
JOIN courses c ON c.id = m.course_id
WHERE c.title = 'Основы PostgreSQL' AND m.position = 1;

INSERT INTO lessons(module_id, title, position, content_ref)
SELECT m.id, 'PRIMARY KEY, FOREIGN KEY, CHECK', 1, 'mongo:lesson:postgres:constraints'
FROM modules m
JOIN courses c ON c.id = m.course_id
WHERE c.title = 'Основы PostgreSQL' AND m.position = 2;

INSERT INTO assignments(course_id, title, description, max_score, is_required)
SELECT c.id, 'Спроектировать схему', 'Создать небольшой набор связанных таблиц PostgreSQL.', 100, TRUE
FROM courses c WHERE c.title = 'Основы PostgreSQL';

INSERT INTO quizzes(course_id, title, pass_score, max_attempts, is_required)
SELECT c.id, 'Проверка по PostgreSQL', 60, 3, TRUE
FROM courses c WHERE c.title = 'Основы PostgreSQL';

INSERT INTO questions(quiz_id, text, position)
SELECT q.id, 'Какой объект однозначно идентифицирует строку?', 1
FROM quizzes q WHERE q.title = 'Проверка по PostgreSQL';

INSERT INTO questions(quiz_id, text, position)
SELECT q.id, 'Какой ключ связывает таблицу с другой таблицей?', 2
FROM quizzes q WHERE q.title = 'Проверка по PostgreSQL';

INSERT INTO question_options(question_id, option_text, position, is_correct)
SELECT q.id, x.option_text, x.position, x.is_correct
FROM questions q
CROSS JOIN (VALUES
    ('PRIMARY KEY', 1, TRUE),
    ('VIEW', 2, FALSE),
    ('INDEX ONLY', 3, FALSE)
) AS x(option_text, position, is_correct)
WHERE q.position = 1;

INSERT INTO question_options(question_id, option_text, position, is_correct)
SELECT q.id, x.option_text, x.position, x.is_correct
FROM questions q
CROSS JOIN (VALUES
    ('FOREIGN KEY', 1, TRUE),
    ('CHECK', 2, FALSE),
    ('TRIGGER ONLY', 3, FALSE)
) AS x(option_text, position, is_correct)
WHERE q.position = 2;

-- Student is enrolled in the published prerequisite course.
INSERT INTO enrollments(user_id, course_id, status)
SELECT u.id, c.id, 'active'
FROM users u
JOIN courses c ON c.title = 'Основы PostgreSQL'
WHERE u.email = 'ivan@example.com';

INSERT INTO lesson_progress(enrollment_id, lesson_id, status, started_at, completed_at)
SELECT e.id, l.id, 'completed', CURRENT_TIMESTAMP - INTERVAL '2 days', CURRENT_TIMESTAMP - INTERVAL '1 day'
FROM enrollments e
JOIN users u ON u.id = e.user_id AND u.email = 'ivan@example.com'
JOIN courses c ON c.id = e.course_id AND c.title = 'Основы PostgreSQL'
JOIN lessons l ON l.module_id IN (SELECT id FROM modules WHERE course_id = c.id);

INSERT INTO submissions(assignment_id, enrollment_id, attempt_no, answer_text, status, score, reviewer_id, reviewed_at)
SELECT a.id, e.id, 1, 'Готовая схема БД.', 'accepted', 92,
       r.id, CURRENT_TIMESTAMP - INTERVAL '1 hour'
FROM assignments a
JOIN courses c ON c.id = a.course_id AND c.title = 'Основы PostgreSQL'
JOIN enrollments e ON e.course_id = c.id
JOIN users s ON s.id = e.user_id AND s.email = 'ivan@example.com'
JOIN users r ON r.email = 'anna@example.com'
WHERE a.title = 'Спроектировать схему';

INSERT INTO attempts(quiz_id, enrollment_id, attempt_no, status, completed_at, score)
SELECT q.id, e.id, 1, 'completed', CURRENT_TIMESTAMP - INTERVAL '2 hours', 100
FROM quizzes q
JOIN courses c ON c.id = q.course_id AND c.title = 'Основы PostgreSQL'
JOIN enrollments e ON e.course_id = c.id
JOIN users u ON u.id = e.user_id AND u.email = 'ivan@example.com'
WHERE q.title = 'Проверка по PostgreSQL';

INSERT INTO answers(attempt_id, question_id, option_id)
SELECT a.id, q.id, qo.id
FROM attempts a
JOIN quizzes z ON z.id = a.quiz_id
JOIN questions q ON q.quiz_id = z.id
JOIN question_options qo ON qo.question_id = q.id AND qo.is_correct = TRUE
JOIN enrollments e ON e.id = a.enrollment_id
WHERE e.user_id = (SELECT id FROM users WHERE email = 'ivan@example.com');

COMMIT;
