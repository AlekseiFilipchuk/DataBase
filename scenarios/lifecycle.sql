-- Run on top of the seeded database.
-- The script demonstrates lifecycle scenarios for User, Course, Enrollment,
-- Submission and Quiz Attempt.

BEGIN;

-- 1. USER lifecycle: registration is an INSERT; student role is assigned automatically.
INSERT INTO users(email, full_name, password_hash)
VALUES ('demo.user@example.com', 'Демо Пользователь', '$2b$12$demo_lifecycle_hash');

-- 2. COURSE lifecycle: draft -> moderation -> published -> archived.
INSERT INTO courses(teacher_id, title, description, status)
SELECT id, 'Демонстрационный курс', 'Курс для показа жизненного цикла.', 'draft'
FROM users
WHERE email = 'anna@example.com';

UPDATE courses
SET status = 'moderation'
WHERE title = 'Демонстрационный курс';

UPDATE courses
SET status = 'published',
    published_at = CURRENT_TIMESTAMP
WHERE title = 'Демонстрационный курс';

-- 3. ENROLLMENT lifecycle: active -> completed.
INSERT INTO enrollments(user_id, course_id, status)
SELECT u.id, c.id, 'active'
FROM users u
JOIN courses c ON c.title = 'Демонстрационный курс'
WHERE u.email = 'demo.user@example.com';

-- The enrollment remains active while learning actions are performed.

-- 4. SUBMISSION lifecycle: created -> on_review -> accepted.
INSERT INTO assignments(course_id, title, description, max_score)
SELECT id, 'Демо-задание', 'Задание для показа жизненного цикла.', 100
FROM courses WHERE title = 'Демонстрационный курс';

INSERT INTO submissions(assignment_id, enrollment_id, attempt_no, answer_text, status)
SELECT a.id, e.id, 1, 'Демо-решение', 'created'
FROM assignments a
JOIN courses c ON c.id = a.course_id AND c.title = 'Демонстрационный курс'
JOIN enrollments e ON e.course_id = c.id
JOIN users u ON u.id = e.user_id AND u.email = 'demo.user@example.com'
WHERE a.title = 'Демо-задание';

UPDATE submissions s
SET status = 'on_review'
WHERE s.attempt_no = 1
  AND s.assignment_id = (SELECT id FROM assignments WHERE title = 'Демо-задание');

UPDATE submissions s
SET status = 'accepted', score = 95,
    reviewer_id = (SELECT id FROM users WHERE email = 'anna@example.com'),
    reviewed_at = CURRENT_TIMESTAMP
WHERE s.attempt_no = 1
  AND s.assignment_id = (SELECT id FROM assignments WHERE title = 'Демо-задание');

-- 5. QUIZ ATTEMPT lifecycle: active -> completed.
INSERT INTO quizzes(course_id, title, pass_score, max_attempts)
SELECT id, 'Демо-тест', 60, 2
FROM courses WHERE title = 'Демонстрационный курс';

INSERT INTO attempts(quiz_id, enrollment_id, attempt_no, status)
SELECT q.id, e.id, 1, 'active'
FROM quizzes q
JOIN courses c ON c.id = q.course_id AND c.title = 'Демонстрационный курс'
JOIN enrollments e ON e.course_id = c.id
JOIN users u ON u.id = e.user_id AND u.email = 'demo.user@example.com'
WHERE q.title = 'Демо-тест';

UPDATE attempts a
SET status = 'completed',
    completed_at = CURRENT_TIMESTAMP,
    score = 90
WHERE a.attempt_no = 1
  AND a.quiz_id = (SELECT id FROM quizzes WHERE title = 'Демо-тест');

-- Final step of the enrollment lifecycle: active -> completed.
UPDATE enrollments e
SET status = 'completed',
    completed_at = CURRENT_TIMESTAMP
FROM users u, courses c
WHERE e.user_id = u.id
  AND e.course_id = c.id
  AND u.email = 'demo.user@example.com'
  AND c.title = 'Демонстрационный курс';

COMMIT;
