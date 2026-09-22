# Словарь таблиц и атрибутов

## users

| Атрибут | Тип | NULL | Ограничения | Назначение |
|---|---|---|---|---|
| id | BIGINT | нет | PK, IDENTITY | Идентификатор пользователя |
| email | VARCHAR(255) | нет | UNIQUE | Email пользователя |
| full_name | VARCHAR(255) | нет | — | Имя пользователя |
| password_hash | VARCHAR(255) | нет | — | Хеш пароля |
| status | VARCHAR(20) | нет | CHECK | Статус учётной записи |
| created_at | TIMESTAMPTZ | нет | DEFAULT | Дата создания |

## roles

| Атрибут | Тип | NULL | Ограничения | Назначение |
|---|---|---|---|---|
| id | BIGINT | нет | PK, IDENTITY | Идентификатор роли |
| code | VARCHAR(50) | нет | UNIQUE | Код роли |
| name | VARCHAR(100) | нет | UNIQUE | Название роли |

## user_roles

| Атрибут | Тип | NULL | Ограничения | Назначение |
|---|---|---|---|---|
| user_id | BIGINT | нет | PK, FK | Пользователь |
| role_id | BIGINT | нет | PK, FK | Роль |

## courses

| Атрибут | Тип | NULL | Ограничения | Назначение |
|---|---|---|---|---|
| id | BIGINT | нет | PK, IDENTITY | Идентификатор курса |
| teacher_id | BIGINT | нет | FK → users | Преподаватель |
| title | VARCHAR(255) | нет | — | Название курса |
| description | TEXT | да | — | Описание |
| status | VARCHAR(30) | нет | CHECK | Статус курса |
| created_at | TIMESTAMPTZ | нет | DEFAULT | Дата создания |
| published_at | TIMESTAMPTZ | да | — | Дата публикации |

## modules

| Атрибут | Тип | NULL | Ограничения | Назначение |
|---|---|---|---|---|
| id | BIGINT | нет | PK, IDENTITY | Идентификатор |
| course_id | BIGINT | нет | FK | Курс |
| title | VARCHAR(255) | нет | — | Название модуля |
| position | INTEGER | нет | CHECK | Порядковый номер |

## lessons

| Атрибут | Тип | NULL | Ограничения | Назначение |
|---|---|---|---|---|
| id | BIGINT | нет | PK, IDENTITY | Идентификатор |
| module_id | BIGINT | нет | FK | Модуль |
| title | VARCHAR(255) | нет | — | Название урока |
| position | INTEGER | нет | CHECK | Порядковый номер |
| is_required | BOOLEAN | нет | DEFAULT | Обязательность |

## enrollments

| Атрибут | Тип | NULL | Ограничения | Назначение |
|---|---|---|---|---|
| id | BIGINT | нет | PK, IDENTITY | Идентификатор записи |
| user_id | BIGINT | нет | FK | Обучающийся |
| course_id | BIGINT | нет | FK | Курс |
| status | VARCHAR(30) | нет | CHECK | Статус обучения |
| enrolled_at | TIMESTAMPTZ | нет | DEFAULT | Дата записи |
| completed_at | TIMESTAMPTZ | да | — | Дата завершения |

## lesson_progress

| Атрибут | Тип | NULL | Ограничения | Назначение |
|---|---|---|---|---|
| enrollment_id | BIGINT | нет | PK, FK | Запись на курс |
| lesson_id | BIGINT | нет | PK, FK | Урок |
| status | VARCHAR(30) | нет | CHECK | Статус прохождения |
| completed_at | TIMESTAMPTZ | да | — | Дата завершения |

## assignments

| Атрибут | Тип | NULL | Ограничения | Назначение |
|---|---|---|---|---|
| id | BIGINT | нет | PK, IDENTITY | Идентификатор задания |
| course_id | BIGINT | нет | FK | Курс |
| title | VARCHAR(255) | нет | — | Название |
| description | TEXT | да | — | Условие |
| is_required | BOOLEAN | нет | DEFAULT | Обязательность |

## submissions

| Атрибут | Тип | NULL | Ограничения | Назначение |
|---|---|---|---|---|
| id | BIGINT | нет | PK, IDENTITY | Идентификатор сдачи |
| assignment_id | BIGINT | нет | FK | Задание |
| enrollment_id | BIGINT | нет | FK | Запись на курс |
| student_id | BIGINT | нет | FK | Обучающийся |
| content | TEXT | нет | — | Решение |
| status | VARCHAR(30) | нет | CHECK | Состояние |
| grade | NUMERIC | да | CHECK | Оценка |
| reviewer_id | BIGINT | да | FK | Проверяющий |
| submitted_at | TIMESTAMPTZ | нет | DEFAULT | Дата сдачи |

## quizzes

| Атрибут | Тип | NULL | Ограничения | Назначение |
|---|---|---|---|---|
| id | BIGINT | нет | PK, IDENTITY | Идентификатор |
| course_id | BIGINT | нет | FK | Курс |
| title | VARCHAR(255) | нет | — | Название |
| passing_score | NUMERIC | нет | CHECK | Проходной балл |
| max_attempts | INTEGER | нет | CHECK | Максимум попыток |

## questions

| Атрибут | Тип | NULL | Ограничения | Назначение |
|---|---|---|---|---|
| id | BIGINT | нет | PK, IDENTITY | Идентификатор |
| quiz_id | BIGINT | нет | FK | Тест |
| text | TEXT | нет | — | Текст вопроса |
| position | INTEGER | нет | CHECK | Позиция |

## question_options

| Атрибут | Тип | NULL | Ограничения | Назначение |
|---|---|---|---|---|
| id | BIGINT | нет | PK, IDENTITY | Идентификатор |
| question_id | BIGINT | нет | FK | Вопрос |
| option_text | TEXT | нет | — | Текст варианта |
| is_correct | BOOLEAN | нет | DEFAULT | Верность |

## attempts

| Атрибут | Тип | NULL | Ограничения | Назначение |
|---|---|---|---|---|
| id | BIGINT | нет | PK, IDENTITY | Идентификатор |
| quiz_id | BIGINT | нет | FK | Тест |
| enrollment_id | BIGINT | нет | FK | Запись на курс |
| status | VARCHAR(30) | нет | CHECK | Состояние |
| score | NUMERIC | да | CHECK | Результат |
| started_at | TIMESTAMPTZ | нет | DEFAULT | Начало |
| completed_at | TIMESTAMPTZ | да | — | Завершение |

## answers

| Атрибут | Тип | NULL | Ограничения | Назначение |
|---|---|---|---|---|
| attempt_id | BIGINT | нет | PK, FK | Попытка |
| question_id | BIGINT | нет | PK, FK | Вопрос |
| option_id | BIGINT | нет | FK | Выбранный вариант |

## course_prerequisites

| Атрибут | Тип | NULL | Ограничения | Назначение |
|---|---|---|---|---|
| course_id | BIGINT | нет | PK, FK, CHECK | Основной курс |
| prerequisite_course_id | BIGINT | нет | PK, FK, CHECK | Обязательный пререквизит |

## Нормализация

Схема находится в третьей нормальной форме:

- каждая таблица описывает одну сущность или одну связь;
- M:N связи вынесены в отдельные таблицы;
- данные пользователей не дублируются в курсах;
- варианты ответов отделены от вопросов;
- ответы отделены от попыток тестирования;
- повторяющиеся и вычисляемые данные не дублируются.