BEGIN;

CREATE TABLE roles (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code        VARCHAR(32)  NOT NULL UNIQUE,
    name        VARCHAR(64)  NOT NULL UNIQUE,
    CONSTRAINT ck_roles_code_format CHECK (code ~ '^[a-z_]+$')
);

CREATE TABLE users (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email           VARCHAR(320) NOT NULL UNIQUE,
    full_name       VARCHAR(200) NOT NULL,
    password_hash   VARCHAR(255) NOT NULL,
    status          VARCHAR(16)  NOT NULL DEFAULT 'active',
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_users_email_not_blank CHECK (length(trim(email)) > 3),
    CONSTRAINT ck_users_status CHECK (status IN ('active', 'blocked'))
);

CREATE TABLE user_roles (
    user_id BIGINT NOT NULL,
    role_id BIGINT NOT NULL,
    PRIMARY KEY (user_id, role_id),
    CONSTRAINT fk_user_roles_user
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_user_roles_role
        FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE RESTRICT
);

CREATE TABLE courses (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    teacher_id      BIGINT       NOT NULL,
    title           VARCHAR(200) NOT NULL,
    description     TEXT         NOT NULL,
    status          VARCHAR(16)  NOT NULL DEFAULT 'draft',
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    published_at    TIMESTAMPTZ,
    archived_at     TIMESTAMPTZ,
    CONSTRAINT fk_courses_teacher
        FOREIGN KEY (teacher_id) REFERENCES users(id) ON DELETE RESTRICT,
    CONSTRAINT uq_courses_teacher_title UNIQUE (teacher_id, title),
    CONSTRAINT ck_courses_title_not_blank CHECK (length(trim(title)) > 0),
    CONSTRAINT ck_courses_status CHECK (status IN ('draft', 'moderation', 'published', 'archived')),
    CONSTRAINT ck_courses_dates CHECK (
        archived_at IS NULL OR published_at IS NOT NULL
    )
);

CREATE TABLE modules (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    course_id   BIGINT       NOT NULL,
    title       VARCHAR(200) NOT NULL,
    position    INTEGER      NOT NULL,
    CONSTRAINT fk_modules_course
        FOREIGN KEY (course_id) REFERENCES courses(id) ON DELETE RESTRICT,
    CONSTRAINT uq_modules_course_position UNIQUE (course_id, position),
    CONSTRAINT ck_modules_position CHECK (position > 0),
    CONSTRAINT ck_modules_title_not_blank CHECK (length(trim(title)) > 0)
);

CREATE TABLE lessons (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    module_id    BIGINT       NOT NULL,
    title        VARCHAR(200) NOT NULL,
    position     INTEGER      NOT NULL,
    content_ref  VARCHAR(128) NOT NULL,
    CONSTRAINT fk_lessons_module
        FOREIGN KEY (module_id) REFERENCES modules(id) ON DELETE RESTRICT,
    CONSTRAINT uq_lessons_module_position UNIQUE (module_id, position),
    CONSTRAINT uq_lessons_content_ref UNIQUE (content_ref),
    CONSTRAINT ck_lessons_position CHECK (position > 0),
    CONSTRAINT ck_lessons_title_not_blank CHECK (length(trim(title)) > 0)
);

CREATE TABLE enrollments (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id      BIGINT      NOT NULL,
    course_id    BIGINT      NOT NULL,
    status       VARCHAR(16) NOT NULL DEFAULT 'active',
    enrolled_at  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMPTZ,
    CONSTRAINT fk_enrollments_user
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT,
    CONSTRAINT fk_enrollments_course
        FOREIGN KEY (course_id) REFERENCES courses(id) ON DELETE RESTRICT,
    CONSTRAINT uq_enrollments_user_course UNIQUE (user_id, course_id),
    CONSTRAINT ck_enrollments_status CHECK (status IN ('active', 'completed', 'cancelled')),
    CONSTRAINT ck_enrollments_completed_at CHECK (
        status <> 'completed' OR completed_at IS NOT NULL
    )
);

CREATE TABLE lesson_progress (
    enrollment_id BIGINT      NOT NULL,
    lesson_id     BIGINT      NOT NULL,
    status        VARCHAR(16) NOT NULL DEFAULT 'not_started',
    started_at    TIMESTAMPTZ,
    completed_at  TIMESTAMPTZ,
    PRIMARY KEY (enrollment_id, lesson_id),
    CONSTRAINT fk_lesson_progress_enrollment
        FOREIGN KEY (enrollment_id) REFERENCES enrollments(id) ON DELETE CASCADE,
    CONSTRAINT fk_lesson_progress_lesson
        FOREIGN KEY (lesson_id) REFERENCES lessons(id) ON DELETE RESTRICT,
    CONSTRAINT ck_lesson_progress_status CHECK (status IN ('not_started', 'in_progress', 'completed')),
    CONSTRAINT ck_lesson_progress_dates CHECK (
        (status = 'not_started' AND started_at IS NULL AND completed_at IS NULL)
        OR
        (status = 'in_progress' AND started_at IS NOT NULL AND completed_at IS NULL)
        OR
        (status = 'completed' AND completed_at IS NOT NULL)
    )
);

CREATE TABLE assignments (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    course_id    BIGINT         NOT NULL,
    title        VARCHAR(200)   NOT NULL,
    description  TEXT           NOT NULL,
    max_score    NUMERIC(5,2)   NOT NULL DEFAULT 100,
    is_required  BOOLEAN        NOT NULL DEFAULT TRUE,
    CONSTRAINT fk_assignments_course
        FOREIGN KEY (course_id) REFERENCES courses(id) ON DELETE RESTRICT,
    CONSTRAINT uq_assignments_course_title UNIQUE (course_id, title),
    CONSTRAINT ck_assignments_title_not_blank CHECK (length(trim(title)) > 0),
    CONSTRAINT ck_assignments_max_score CHECK (max_score > 0 AND max_score <= 1000)
);

CREATE TABLE submissions (
    id             BIGINT        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    assignment_id  BIGINT        NOT NULL,
    enrollment_id  BIGINT        NOT NULL,
    attempt_no     INTEGER       NOT NULL,
    answer_text    TEXT          NOT NULL,
    status         VARCHAR(16)   NOT NULL DEFAULT 'created',
    score          NUMERIC(5,2),
    reviewer_id    BIGINT,
    submitted_at   TIMESTAMPTZ   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    reviewed_at    TIMESTAMPTZ,
    CONSTRAINT fk_submissions_assignment
        FOREIGN KEY (assignment_id) REFERENCES assignments(id) ON DELETE RESTRICT,
    CONSTRAINT fk_submissions_enrollment
        FOREIGN KEY (enrollment_id) REFERENCES enrollments(id) ON DELETE RESTRICT,
    CONSTRAINT fk_submissions_reviewer
        FOREIGN KEY (reviewer_id) REFERENCES users(id) ON DELETE RESTRICT,
    CONSTRAINT uq_submissions_attempt UNIQUE (assignment_id, enrollment_id, attempt_no),
    CONSTRAINT ck_submissions_attempt_no CHECK (attempt_no > 0),
    CONSTRAINT ck_submissions_status CHECK (status IN ('created', 'on_review', 'accepted', 'revision')),
    CONSTRAINT ck_submissions_score CHECK (score IS NULL OR (score >= 0 AND score <= 100))
);

CREATE TABLE quizzes (
    id           BIGINT        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    course_id    BIGINT        NOT NULL,
    title        VARCHAR(200)  NOT NULL,
    pass_score   NUMERIC(5,2)  NOT NULL DEFAULT 60,
    max_attempts INTEGER       NOT NULL DEFAULT 3,
    is_required  BOOLEAN       NOT NULL DEFAULT TRUE,
    CONSTRAINT fk_quizzes_course
        FOREIGN KEY (course_id) REFERENCES courses(id) ON DELETE RESTRICT,
    CONSTRAINT uq_quizzes_course_title UNIQUE (course_id, title),
    CONSTRAINT ck_quizzes_title_not_blank CHECK (length(trim(title)) > 0),
    CONSTRAINT ck_quizzes_pass_score CHECK (pass_score >= 0 AND pass_score <= 100),
    CONSTRAINT ck_quizzes_max_attempts CHECK (max_attempts > 0)
);

CREATE TABLE questions (
    id         BIGINT        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    quiz_id    BIGINT        NOT NULL,
    text       TEXT          NOT NULL,
    position   INTEGER       NOT NULL,
    CONSTRAINT fk_questions_quiz
        FOREIGN KEY (quiz_id) REFERENCES quizzes(id) ON DELETE CASCADE,
    CONSTRAINT uq_questions_quiz_position UNIQUE (quiz_id, position),
    CONSTRAINT ck_questions_position CHECK (position > 0),
    CONSTRAINT ck_questions_text_not_blank CHECK (length(trim(text)) > 0)
);

CREATE TABLE question_options (
    id            BIGINT       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    question_id   BIGINT       NOT NULL,
    option_text   VARCHAR(500) NOT NULL,
    position      INTEGER      NOT NULL,
    is_correct    BOOLEAN      NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_question_options_question
        FOREIGN KEY (question_id) REFERENCES questions(id) ON DELETE CASCADE,
    CONSTRAINT uq_question_options_position UNIQUE (question_id, position),
    CONSTRAINT uq_question_options_question_id UNIQUE (question_id, id),
    CONSTRAINT ck_question_options_position CHECK (position > 0),
    CONSTRAINT ck_question_options_text_not_blank CHECK (length(trim(option_text)) > 0)
);

CREATE TABLE attempts (
    id             BIGINT        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    quiz_id        BIGINT        NOT NULL,
    enrollment_id  BIGINT        NOT NULL,
    attempt_no     INTEGER       NOT NULL,
    status         VARCHAR(16)   NOT NULL DEFAULT 'active',
    started_at     TIMESTAMPTZ   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    completed_at   TIMESTAMPTZ,
    score          NUMERIC(5,2),
    CONSTRAINT fk_attempts_quiz
        FOREIGN KEY (quiz_id) REFERENCES quizzes(id) ON DELETE RESTRICT,
    CONSTRAINT fk_attempts_enrollment
        FOREIGN KEY (enrollment_id) REFERENCES enrollments(id) ON DELETE RESTRICT,
    CONSTRAINT uq_attempts_number UNIQUE (quiz_id, enrollment_id, attempt_no),
    CONSTRAINT ck_attempts_no CHECK (attempt_no > 0),
    CONSTRAINT ck_attempts_status CHECK (status IN ('active', 'completed', 'abandoned')),
    CONSTRAINT ck_attempts_score CHECK (score IS NULL OR (score >= 0 AND score <= 100)),
    CONSTRAINT ck_attempts_completed_at CHECK (
        status <> 'completed' OR completed_at IS NOT NULL
    )
);

CREATE TABLE answers (
    attempt_id   BIGINT NOT NULL,
    question_id  BIGINT NOT NULL,
    option_id    BIGINT NOT NULL,
    answered_at  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (attempt_id, question_id),
    CONSTRAINT fk_answers_attempt
        FOREIGN KEY (attempt_id) REFERENCES attempts(id) ON DELETE CASCADE,
    CONSTRAINT fk_answers_question
        FOREIGN KEY (question_id) REFERENCES questions(id) ON DELETE RESTRICT,
    CONSTRAINT fk_answers_option_for_question
        FOREIGN KEY (question_id, option_id)
        REFERENCES question_options(question_id, id)
        ON DELETE RESTRICT
);

CREATE INDEX ix_modules_course_id ON modules(course_id);
CREATE INDEX ix_lessons_module_id ON lessons(module_id);
CREATE INDEX ix_enrollments_course_id ON enrollments(course_id);
CREATE INDEX ix_lesson_progress_lesson_id ON lesson_progress(lesson_id);
CREATE INDEX ix_assignments_course_id ON assignments(course_id);
CREATE INDEX ix_submissions_enrollment_id ON submissions(enrollment_id);
CREATE INDEX ix_quizzes_course_id ON quizzes(course_id);
CREATE INDEX ix_questions_quiz_id ON questions(quiz_id);
CREATE INDEX ix_attempts_enrollment_id ON attempts(enrollment_id);

CREATE UNIQUE INDEX ux_attempts_one_active
    ON attempts (quiz_id, enrollment_id)
    WHERE status = 'active';

CREATE OR REPLACE FUNCTION assign_default_student_role()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    student_role_id BIGINT;
BEGIN
    SELECT id INTO student_role_id FROM roles WHERE code = 'student';
    IF student_role_id IS NULL THEN
        RAISE EXCEPTION 'Role student must exist before inserting users';
    END IF;

    INSERT INTO user_roles(user_id, role_id)
    VALUES (NEW.id, student_role_id)
    ON CONFLICT DO NOTHING;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_users_default_student_role
AFTER INSERT ON users
FOR EACH ROW
EXECUTE FUNCTION assign_default_student_role();

CREATE OR REPLACE FUNCTION require_teacher_role_for_course()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM user_roles ur
        JOIN roles r ON r.id = ur.role_id
        WHERE ur.user_id = NEW.teacher_id
          AND r.code = 'teacher'
    ) THEN
        RAISE EXCEPTION 'Course teacher_id=% must belong to teacher role', NEW.teacher_id;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_courses_teacher_role
BEFORE INSERT OR UPDATE OF teacher_id ON courses
FOR EACH ROW
EXECUTE FUNCTION require_teacher_role_for_course();

CREATE OR REPLACE FUNCTION check_active_enrollment_course()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    course_status VARCHAR(16);
BEGIN
    IF NEW.status = 'active' THEN
        SELECT status INTO course_status FROM courses WHERE id = NEW.course_id;
        IF course_status IS DISTINCT FROM 'published' THEN
            RAISE EXCEPTION 'Active enrollment is allowed only for published courses';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_enrollments_course_status
BEFORE INSERT OR UPDATE OF course_id, status ON enrollments
FOR EACH ROW
EXECUTE FUNCTION check_active_enrollment_course();

CREATE OR REPLACE FUNCTION check_lesson_progress_scope()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    lesson_course_id BIGINT;
    enrollment_course_id BIGINT;
BEGIN
    SELECT m.course_id INTO lesson_course_id
    FROM lessons l
    JOIN modules m ON m.id = l.module_id
    WHERE l.id = NEW.lesson_id;

    SELECT course_id INTO enrollment_course_id
    FROM enrollments
    WHERE id = NEW.enrollment_id;

    IF lesson_course_id IS DISTINCT FROM enrollment_course_id THEN
        RAISE EXCEPTION 'Lesson % does not belong to enrollment course %',
            NEW.lesson_id, enrollment_course_id;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_lesson_progress_scope
BEFORE INSERT OR UPDATE ON lesson_progress
FOR EACH ROW
EXECUTE FUNCTION check_lesson_progress_scope();

CREATE OR REPLACE FUNCTION check_submission_scope()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    assignment_course_id BIGINT;
    enrollment_course_id BIGINT;
BEGIN
    SELECT course_id INTO assignment_course_id
    FROM assignments
    WHERE id = NEW.assignment_id;

    SELECT course_id INTO enrollment_course_id
    FROM enrollments
    WHERE id = NEW.enrollment_id;

    IF assignment_course_id IS DISTINCT FROM enrollment_course_id THEN
        RAISE EXCEPTION 'Assignment % and enrollment % belong to different courses',
            NEW.assignment_id, NEW.enrollment_id;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_submissions_scope
BEFORE INSERT OR UPDATE ON submissions
FOR EACH ROW
EXECUTE FUNCTION check_submission_scope();

CREATE OR REPLACE FUNCTION check_reviewer_role()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.reviewer_id IS NOT NULL AND NOT EXISTS (
        SELECT 1
        FROM user_roles ur
        JOIN roles r ON r.id = ur.role_id
        WHERE ur.user_id = NEW.reviewer_id
          AND r.code = 'teacher'
    ) THEN
        RAISE EXCEPTION 'Reviewer % must have teacher role', NEW.reviewer_id;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_submissions_reviewer_role
BEFORE INSERT OR UPDATE OF reviewer_id ON submissions
FOR EACH ROW
EXECUTE FUNCTION check_reviewer_role();

CREATE OR REPLACE FUNCTION check_attempt_scope_and_limit()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    quiz_course_id BIGINT;
    enrollment_course_id BIGINT;
    max_allowed INTEGER;
    used_attempts INTEGER;
BEGIN
    SELECT course_id, max_attempts
      INTO quiz_course_id, max_allowed
    FROM quizzes
    WHERE id = NEW.quiz_id;

    SELECT course_id INTO enrollment_course_id
    FROM enrollments
    WHERE id = NEW.enrollment_id;

    IF quiz_course_id IS DISTINCT FROM enrollment_course_id THEN
        RAISE EXCEPTION 'Quiz % and enrollment % belong to different courses',
            NEW.quiz_id, NEW.enrollment_id;
    END IF;

    SELECT count(*)
      INTO used_attempts
    FROM attempts
    WHERE quiz_id = NEW.quiz_id
      AND enrollment_id = NEW.enrollment_id;

    IF TG_OP = 'INSERT' AND used_attempts >= max_allowed THEN
        RAISE EXCEPTION 'Attempt limit exceeded for quiz %: maximum %',
            NEW.quiz_id, max_allowed;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_attempts_scope_and_limit
BEFORE INSERT ON attempts
FOR EACH ROW
EXECUTE FUNCTION check_attempt_scope_and_limit();

CREATE OR REPLACE FUNCTION prevent_invalid_answer_option()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM question_options qo
        WHERE qo.question_id = NEW.question_id
          AND qo.id = NEW.option_id
    ) THEN
        RAISE EXCEPTION 'Answer option % does not belong to question %',
            NEW.option_id, NEW.question_id;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM attempts a
        JOIN quizzes qz ON qz.id = a.quiz_id
        JOIN questions q ON q.quiz_id = qz.id
        WHERE a.id = NEW.attempt_id
          AND q.id = NEW.question_id
    ) THEN
        RAISE EXCEPTION 'Question % does not belong to the quiz of attempt %',
            NEW.question_id, NEW.attempt_id;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_answers_scope
BEFORE INSERT OR UPDATE ON answers
FOR EACH ROW
EXECUTE FUNCTION prevent_invalid_answer_option();

INSERT INTO roles(code, name) VALUES
    ('student', 'Обучающийся'),
    ('teacher', 'Преподаватель'),
    ('moderator', 'Модератор'),
    ('admin', 'Администратор');

COMMIT;
