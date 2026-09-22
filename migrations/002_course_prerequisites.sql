BEGIN;

CREATE TABLE course_prerequisites (
    course_id              BIGINT NOT NULL,
    prerequisite_course_id BIGINT NOT NULL,

    PRIMARY KEY (course_id, prerequisite_course_id),

    CONSTRAINT fk_course_prereq_course
        FOREIGN KEY (course_id)
        REFERENCES courses(id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_course_prereq_prerequisite
        FOREIGN KEY (prerequisite_course_id)
        REFERENCES courses(id)
        ON DELETE RESTRICT,

    CONSTRAINT ck_course_prereq_not_self
        CHECK (course_id <> prerequisite_course_id)
);

CREATE INDEX ix_course_prerequisites_prerequisite
    ON course_prerequisites(prerequisite_course_id);


-- Запрет циклических зависимостей курсов.
CREATE OR REPLACE FUNCTION prevent_course_prerequisite_cycle()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (
        WITH RECURSIVE deps(node) AS (
            SELECT cp.prerequisite_course_id
            FROM course_prerequisites cp
            WHERE cp.course_id = NEW.prerequisite_course_id

            UNION

            SELECT cp.prerequisite_course_id
            FROM course_prerequisites cp
            JOIN deps d
                ON d.node = cp.course_id
        )
        SELECT 1
        FROM deps
        WHERE node = NEW.course_id
    ) THEN
        RAISE EXCEPTION
            'Cyclic course prerequisite dependency is not allowed';
    END IF;

    RETURN NEW;
END;
$$;


CREATE TRIGGER trg_course_prerequisites_no_cycle
BEFORE INSERT ON course_prerequisites
FOR EACH ROW
EXECUTE FUNCTION prevent_course_prerequisite_cycle();


-- Запись на курс разрешена только после
-- завершения всех его обязательных пререквизитов.
CREATE OR REPLACE FUNCTION check_course_prerequisites_completed()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.status = 'active'
       AND EXISTS (
           SELECT 1
           FROM course_prerequisites cp
           WHERE cp.course_id = NEW.course_id
             AND NOT EXISTS (
                 SELECT 1
                 FROM enrollments e_prev
                 WHERE e_prev.user_id = NEW.user_id
                   AND e_prev.course_id = cp.prerequisite_course_id
                   AND e_prev.status = 'completed'
             )
       )
    THEN
        RAISE EXCEPTION
            'Cannot enroll user %: prerequisite course is not completed',
            NEW.user_id;
    END IF;

    RETURN NEW;
END;
$$;


CREATE TRIGGER trg_enrollments_prerequisites
BEFORE INSERT OR UPDATE OF user_id, course_id, status
ON enrollments
FOR EACH ROW
EXECUTE FUNCTION check_course_prerequisites_completed();

COMMIT;