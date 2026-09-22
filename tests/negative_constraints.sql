-- Negative tests for integrity constraints.
-- Каждый блок специально пытается нарушить ограничение.
-- Ошибка перехватывается, после чего выполняется следующая проверка.

DO $$
BEGIN
    BEGIN
        INSERT INTO users(email, full_name, password_hash)
        SELECT email, 'Дубликат', 'hash'
        FROM users
        WHERE email = 'ivan@example.com';

        RAISE EXCEPTION
            'TEST FAILED: duplicate email was accepted';

    EXCEPTION
        WHEN unique_violation THEN
            RAISE NOTICE
                'PASS 1: UNIQUE users.email';
    END;
END
$$;


DO $$
BEGIN
    BEGIN
        INSERT INTO users(email, full_name, password_hash)
        VALUES ('null.name@example.com', NULL, 'hash');

        RAISE EXCEPTION
            'TEST FAILED: NULL full_name was accepted';

    EXCEPTION
        WHEN not_null_violation THEN
            RAISE NOTICE
                'PASS 2: NOT NULL users.full_name';
    END;
END
$$;


DO $$
BEGIN
    BEGIN
        INSERT INTO courses(
            teacher_id,
            title,
            description,
            status
        )
        SELECT
            id,
            'Bad status course',
            'Negative test',
            'unknown'
        FROM users
        WHERE email = 'anna@example.com';

        RAISE EXCEPTION
            'TEST FAILED: invalid course status was accepted';

    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE
                'PASS 3: CHECK courses.status';
    END;
END
$$;


DO $$
BEGIN
    BEGIN
        INSERT INTO modules(
            course_id,
            title,
            position
        )
        SELECT
            id,
            'Bad position',
            0
        FROM courses
        WHERE title = 'Основы PostgreSQL';

        RAISE EXCEPTION
            'TEST FAILED: position=0 was accepted';

    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE
                'PASS 4: CHECK modules.position';
    END;
END
$$;


DO $$
BEGIN
    BEGIN
        INSERT INTO user_roles(
            user_id,
            role_id
        )
        VALUES (999999999, 1);

        RAISE EXCEPTION
            'TEST FAILED: invalid user FK was accepted';

    EXCEPTION
        WHEN foreign_key_violation THEN
            RAISE NOTICE
                'PASS 5: FOREIGN KEY user_roles.user_id';
    END;
END
$$;


DO $$
BEGIN
    BEGIN
        INSERT INTO enrollments(
            user_id,
            course_id,
            status
        )
        SELECT
            u.id,
            c.id,
            'active'
        FROM users u
        JOIN courses c
            ON c.title = 'Основы PostgreSQL'
        WHERE u.email = 'ivan@example.com';

        RAISE EXCEPTION
            'TEST FAILED: duplicate enrollment was accepted';

    EXCEPTION
        WHEN unique_violation THEN
            RAISE NOTICE
                'PASS 6: UNIQUE enrollments(user_id, course_id)';
    END;
END
$$;


-- Проверяем, что answer не может ссылаться
-- на вариант ответа другого вопроса.
DO $$
DECLARE
    caught BOOLEAN := FALSE;
BEGIN

    BEGIN
        INSERT INTO answers(
            attempt_id,
            question_id,
            option_id
        )
        SELECT
            a.id,
            q.id,
            other.id
        FROM attempts a
        JOIN questions q
            ON q.quiz_id = a.quiz_id
        JOIN question_options other
            ON other.question_id <> q.id
        LIMIT 1;

    EXCEPTION
        WHEN foreign_key_violation THEN
            caught := TRUE;
        WHEN raise_exception THEN
            caught := TRUE;
    END;


    IF NOT caught THEN
        RAISE EXCEPTION
            'TEST FAILED: option from another question was accepted';
    END IF;


    RAISE NOTICE
        'PASS 7: answer scope is protected';
END
$$;


-- Проверяем запрет записи на курс
-- без завершённого пререквизита.
DO $$
DECLARE
    advanced_course_id BIGINT;
    caught BOOLEAN := FALSE;
BEGIN

    SELECT id
    INTO advanced_course_id
    FROM courses
    WHERE title = 'Продвинутый PostgreSQL';


    -- Публикуем курс, чтобы тестировал именно
    -- механизм проверки пререквизитов.
    UPDATE courses
    SET
        status = 'published',
        published_at = CURRENT_TIMESTAMP
    WHERE id = advanced_course_id;


    BEGIN
        INSERT INTO enrollments(
            user_id,
            course_id,
            status
        )
        SELECT
            id,
            advanced_course_id,
            'active'
        FROM users
        WHERE email = 'ivan@example.com';

    EXCEPTION
        WHEN raise_exception THEN
            caught := TRUE;
    END;


    IF NOT caught THEN
        RAISE EXCEPTION
            'TEST FAILED: enrollment without completed prerequisite was accepted';
    END IF;


    RAISE NOTICE
        'PASS 8: prerequisite completion is required for enrollment';
END
$$;


-- Проверяем запрет курса-пререквизита самого себя.
DO $$
DECLARE
    course_id BIGINT;
    caught BOOLEAN := FALSE;
BEGIN

    SELECT id
    INTO course_id
    FROM courses
    WHERE title = 'Основы PostgreSQL';


    BEGIN
        INSERT INTO course_prerequisites(
            course_id,
            prerequisite_course_id
        )
        VALUES (
            course_id,
            course_id
        );

    EXCEPTION
        WHEN check_violation THEN
            caught := TRUE;
    END;


    IF NOT caught THEN
        RAISE EXCEPTION
            'TEST FAILED: self-prerequisite was accepted';
    END IF;


    RAISE NOTICE
        'PASS 9: self-prerequisite is rejected';
END
$$;


-- Проверяем запрет циклических зависимостей.
DO $$
DECLARE
    course_a BIGINT;
    course_b BIGINT;
    caught BOOLEAN := FALSE;
BEGIN

    SELECT id
    INTO course_a
    FROM courses
    WHERE title = 'Продвинутый PostgreSQL';


    SELECT id
    INTO course_b
    FROM courses
    WHERE title = 'Основы алгоритмов';


    -- Разрешённая зависимость:
    -- A -> B
    INSERT INTO course_prerequisites(
        course_id,
        prerequisite_course_id
    )
    VALUES (
        course_a,
        course_b
    );


    -- Запрещённая зависимость:
    -- B -> A
    -- Получится цикл A -> B -> A.
    BEGIN
        INSERT INTO course_prerequisites(
            course_id,
            prerequisite_course_id
        )
        VALUES (
            course_b,
            course_a
        );

    EXCEPTION
        WHEN raise_exception THEN
            caught := TRUE;
    END;


    IF NOT caught THEN
        RAISE EXCEPTION
            'TEST FAILED: cyclic prerequisite dependency was accepted';
    END IF;


    RAISE NOTICE
        'PASS 10: prerequisite cycle is rejected';
END
$$;