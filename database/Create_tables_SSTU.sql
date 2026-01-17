-- Создание базы данных
CREATE DATABASE IF NOT EXISTS student_SSTU;
USE student_SSTU;

-- форма обучения
CREATE TABLE IF NOT EXISTS `Form_study`(
	id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(50) NOT NULL UNIQUE
);

-- Специальности
CREATE TABLE IF NOT EXISTS `Specialty`(
	id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(50) NOT NULL UNIQUE COMMENT "Полное название специальности",
    cut VARCHAR(50) NOT NULL UNIQUE COMMENT "Сокращение",
    cod_specialty VARCHAR(20) NOT NULL COMMENT 'Код специальности'
);


CREATE TABLE IF NOT EXISTS `tutor` (
	id INT AUTO_INCREMENT PRIMARY KEY,
    
    -- Личные данные
    surname VARCHAR(50) NOT NULL COMMENT 'Фамилия',
    first_name VARCHAR(50) NOT NULL COMMENT 'Имя',
    middle_name VARCHAR(50) COMMENT 'Отчество'
);

-- Таблица студенческих групп
CREATE TABLE IF NOT EXISTS `Student_group`(
    id INT AUTO_INCREMENT PRIMARY KEY,
    naming VARCHAR(20) NOT NULL COMMENT 'Название группы',
    specialty_id INT NOT NULL COMMENT "Специальность",
    form_study_id INT NOT NULL COMMENT "Форма обучения",
    tutor_id INT NOT NULL COMMENT "Куратор",
    course INT NOT NULL COMMENT "Курс",
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        
    FOREIGN KEY (specialty_id) REFERENCES `Specialty`(id),
    FOREIGN KEY (form_study_id) REFERENCES `Form_study`(id),
    FOREIGN KEY (tutor_id) REFERENCES `tutor`(id)
);

-- Таблица студентов (основная информация)
CREATE TABLE IF NOT EXISTS `Student`(
	id INT AUTO_INCREMENT PRIMARY KEY,
    
    -- Личные данные
    surname VARCHAR(50) NOT NULL COMMENT 'Фамилия',
    first_name VARCHAR(50) NOT NULL COMMENT 'Имя',
    middle_name VARCHAR(50) COMMENT 'Отчество',
	birth_date DATE NOT NULL COMMENT 'Дата рождения',
    
    -- Учебная информация
	student_group_id INT NOT NULL COMMENT 'Группа в которой учится студент',
	gradebook_number VARCHAR(20) NOT NULL UNIQUE COMMENT 'Зачётка',
    
    -- Контакты
	phone VARCHAR(20) NOT NULL UNIQUE COMMENT 'Номер телефона',
	email VARCHAR(100) NOT NULL UNIQUE COMMENT 'Почта',
    address TEXT NOT NULL COMMENT 'Адрес',    
    
	-- Безопасность
    student_password VARCHAR(255) NOT NULL COMMENT 'Хэш пароля',
    profile_photo VARCHAR(255) COMMENT 'Путь к фото профиля',
    
    -- Технические поля
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- создаем связи 
    -- ON DELETE CASCADE -- если удалиться форма обучения, удаляться студенты с этой формой обучения
    FOREIGN KEY (student_group_id) REFERENCES `Student_group`(id)
);

-- Категории деятельности (Научная, Общественная, Культурная, Спортивная)
CREATE TABLE IF NOT EXISTS `Activity_Category` (
    id INT AUTO_INCREMENT PRIMARY KEY,
    naming VARCHAR(100) NOT NULL COMMENT 'Название категории (напр. Научно-исследовательская)',
    cod VARCHAR(50) NOT NULL UNIQUE COMMENT 'Код для системы (science, social, cultural, sport)'
);

-- справочник уровней мероприятия
CREATE TABLE IF NOT EXISTS `level_type`(
	id INT AUTO_INCREMENT PRIMARY KEY,
	title VARCHAR(50) NOT NULL UNIQUE
);

-- Справочник критериев (Сюда заносятся данные из PDF таблиц)
CREATE TABLE IF NOT EXISTS `Rating_Criteria` (
    id INT AUTO_INCREMENT PRIMARY KEY,
    category_id INT NOT NULL,
    
    -- Описание критерия
    section_naming VARCHAR(255) COMMENT 'Название раздела (напр. Предметные олимпиады)',
    description_text VARCHAR(255) NOT NULL COMMENT 'Конкретное достижение (напр. Гран-при, 1 место, Участие)',
    
    -- Уровень мероприятия (из PDF часто влияет на балл)
    level_type_id INT NOT NULL COMMENT "('university', 'city', 'regional', 'federal', 'international', 'other')",
    
    -- Баллы
    points INT NOT NULL DEFAULT 0 COMMENT 'Количество баллов за единицу (из PDF)',
    
    FOREIGN KEY (category_id) REFERENCES `Activity_Category`(id) ON DELETE CASCADE,
    FOREIGN KEY (level_type_id) REFERENCES `level_type`(id) ON DELETE CASCADE
) COMMENT 'Таблица правил начисления баллов';

-- Семестры (чтобы разделять рейтинги по периодам)
CREATE TABLE IF NOT EXISTS `Academic_Period` (
    id INT AUTO_INCREMENT PRIMARY KEY,
    naming VARCHAR(50) NOT NULL COMMENT 'Например: Осенний семестр 2023',
    start_date DATE NOT NULL,
    end_date DATE NOT NULL
);

-- Достижения студента (Связь Студента и Критерия)
CREATE TABLE IF NOT EXISTS `Student_Achievement` (
    id INT AUTO_INCREMENT PRIMARY KEY,
    student_id INT NOT NULL,
    criteria_id INT NOT NULL,
    period_id INT NOT NULL,
    
    -- Количественные данные
    quantity INT DEFAULT 1 COMMENT 'Количество (если студент ввел 2 статьи)',
    
    -- Подтверждение
    document_title VARCHAR(255) COMMENT 'Название документа (грамота №...)',
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (student_id) REFERENCES `Student`(id) ON DELETE CASCADE,
    FOREIGN KEY (criteria_id) REFERENCES `Rating_Criteria`(id),
    FOREIGN KEY (period_id) REFERENCES `Academic_Period`(id)
);


CREATE OR REPLACE VIEW Student_Rating_Summary AS
SELECT 
    s.id AS student_id,
    s.surname,
    s.first_name,
    s.student_group_id,
    ap.id AS period_id,
    ap.naming AS period_naming,
    cat.naming AS category_naming,
    SUM(rc.points * sa.quantity) AS total_points
FROM Student s
JOIN Student_Achievement sa ON s.id = sa.student_id
JOIN Rating_Criteria rc ON sa.criteria_id = rc.id
JOIN Activity_Category cat ON rc.category_id = cat.id
JOIN Academic_Period ap ON sa.period_id = ap.id
GROUP BY 
    s.id, s.surname, s.first_name, s.student_group_id,
    ap.id, ap.naming, cat.id, cat.naming;
    
    
    
INSERT INTO Form_study (title) VALUES
('Очная'),
('Очно-заочная'),
('Заочная'),
('Сокращенная форма');

INSERT INTO Specialty (title, cut, cod_specialty) VALUES
('Информатика и вычислительная техника', 'ИВЧТ', '09.03.01'),
('Программная инженерия', 'ПИНЖ', '09.03.04'),
('Информационные системы и технологии', 'ИСТ', '09.03.02');

INSERT INTO tutor (surname, first_name, middle_name) VALUES
('Иванов', 'Пётр', 'Сергеевич'),
('Сидорова', 'Мария', 'Александровна'),
('Кузнецов', 'Илья', 'Геннадьевич');

INSERT INTO Student_group (naming, specialty_id, form_study_id, tutor_id, course) VALUES
('ИВЧТ-11', 1, 1, 1, 1),
('ПИНЖ-21', 2, 1, 2, 2),
('ИСТ-31', 3, 3, 3, 3);

INSERT INTO Student (surname, first_name, middle_name, birth_date, student_group_id, gradebook_number, phone, email, address, student_password) VALUES
('Петров', 'Алексей', 'Дмитриевич', '2005-01-12', 1, '12345', '+79170000001', 'petrov@example.com', 'ул. Ленина, 10', '123'),
('Соколова', 'Елена', 'Игоревна', '2004-05-22', 1, '12346', '+79170000002', 'sokolova@example.com', 'ул. Пушкина, 15', '123'),
('Орлов', 'Никита', 'Павлович', '2003-11-02', 2, '22347', '+79170000003', 'orlov@example.com', 'ул. Гагарина, 20', '123');

-- Курс 1 (Группа ИВТ-11, ID 1)
INSERT INTO Student (surname, first_name, middle_name, birth_date, student_group_id, gradebook_number, phone, email, address, student_password) VALUES 
('Громов', 'Антон', 'Викторович', '2005-03-01', 1, 'Z12347', '+79170000004', 'gromov@uni.ru', 'ул. Мира, 5', '123');

-- Курс 2 (Группа ПИ-21, ID 2)
INSERT INTO Student (surname, first_name, middle_name, birth_date, student_group_id, gradebook_number, phone, email, address, student_password) VALUES 
('Зайцева', 'Виктория', 'Олеговна', '2004-09-10', 2, 'Z22348', '+79170000005', 'zaytseva@uni.ru', 'пр. Победы, 12', '123');

-- Курс 3 (Группа ИСТ-31, ID 3)
INSERT INTO Student (surname, first_name, middle_name, birth_date, student_group_id, gradebook_number, phone, email, address, student_password) VALUES 
('Федоров', 'Павел', 'Андреевич', '2003-06-25', 3, 'Z32349', '+79170000006', 'fedorov@uni.ru', 'ул. Заводская, 3', '123');

INSERT INTO Activity_Category (naming, cod) VALUES
('Научная деятельность', 'science'),           -- ID 1
('Культурная деятельность', 'cultural'),       -- ID 2
('Общественная деятельность', 'social'),       -- ID 3
('Спортивная деятельность', 'sport');          -- ID 4

INSERT INTO level_type (title) VALUES
('Университетский'),     -- ID 1
('Городской'),           -- ID 2
('Региональный'),        -- ID 3
('Федеральный'),         -- ID 4
('Международный');       -- ID 5


-- ==========================================================
-- 1. Заполняем критерии для НАУЧНОЙ деятельности (category_id = 1)
-- Очищен description_text от указаний на уровень
-- ==========================================================
INSERT INTO Rating_Criteria (category_id, section_naming, description_text, level_type_id, points) VALUES

-- Участие в олимпиадах
(1, 'Участие в олимпиадах', 'Участие в предметных олимпиадах, конкурсах курсовых и иных работ', 1, 1),
(1, 'Участие в олимпиадах', 'Участие в предметных олимпиадах, конкурсах курсовых и иных работ', 4, 2),
(1, 'Участие в олимпиадах', 'Участие в международных экзаменах PET, FCE, TOEFL с получением сертификата', 5, 3),

-- Призовые места олимпиад
-- Уровни: Университетский (1), Федеральный (4), Международный (5)
(1, 'Призовые места олимпиад', 'Гран-при', 1, 4),
(1, 'Призовые места олимпиад', '1 место', 1, 3),
(1, 'Призовые места олимпиад', '2 место', 1, 2),
(1, 'Призовые места олимпиад', '3 место', 1, 1),

(1, 'Призовые места олимпиад', 'Гран-при', 4, 5),
(1, 'Призовые места олимпиад', '1 место', 4, 4),
(1, 'Призовые места олимпиад', '2 место', 4, 3),
(1, 'Призовые места олимпиад', '3 место', 4, 2),

(1, 'Призовые места олимпиад', 'Гран-при', 5, 6),
(1, 'Призовые места олимпиад', '1 место', 5, 5),
(1, 'Призовые места олимпиад', '2 место', 5, 4),
(1, 'Призовые места олимпиад', '3 место', 5, 3),

-- Участие в конференциях с докладом
-- Уровни: Университетский (1), Городской (2), Региональный (3), Федеральный (4), Международный (5)
(1, 'Конференции', 'Участие с докладом в конференции', 1, 3),
(1, 'Конференции', 'Участие с докладом в конференции', 1, 4), -- Межвуз
(1, 'Конференции', 'Участие с докладом в конференции', 2, 5),
(1, 'Конференции', 'Участие с докладом в конференции', 3, 6), -- Областная
(1, 'Конференции', 'Участие с докладом в конференции', 3, 7), -- Региональная
(1, 'Конференции', 'Участие с докладом в конференции', 4, 8),
(1, 'Конференции', 'Участие с докладом в конференции', 5, 9),

-- Призовые места на конференциях
(1, 'Призовые места конференций', 'Гран-при', 1, 4),
(1, 'Призовые места конференций', '1 место', 1, 3),
(1, 'Призовые места конференций', '2 место', 1, 2),
(1, 'Призовые места конференций', '3 место', 1, 1),
(1, 'Призовые места конференций', 'Специальная грамота', 1, 2),

(1, 'Призовые места конференций', 'Гран-при', 2, 6),
(1, 'Призовые места конференций', '1 место', 2, 5),
(1, 'Призовые места конференций', '2 место', 2, 4),
(1, 'Призовые места конференций', '3 место', 2, 3),
(1, 'Призовые места конференций', 'Специальная грамота', 2, 4),

(1, 'Призовые места конференций', 'Гран-при', 3, 7),
(1, 'Призовые места конференций', '1 место', 3, 6),
(1, 'Призовые места конференций', '2 место', 3, 5),
(1, 'Призовые места конференций', '3 место', 3, 4),
(1, 'Призовые места конференций', 'Специальная грамота', 3, 5),

(1, 'Призовые места конференций', 'Гран-при', 4, 9),
(1, 'Призовые места конференций', '1 место', 4, 8),
(1, 'Призовые места конференций', '2 место', 4, 7),
(1, 'Призовые места конференций', '3 место', 4, 6),
(1, 'Призовые места конференций', 'Специальная грамота', 4, 7),

(1, 'Призовые места конференций', 'Гран-при', 5, 10),
(1, 'Призовые места конференций', '1 место', 5, 9),
(1, 'Призовые места конференций', '2 место', 5, 8),
(1, 'Призовые места конференций', '3 место', 5, 7),
(1, 'Призовые места конференций', 'Специальная грамота', 5, 8),

-- Участие в научных семинарах
(1, 'Научные семинары', 'Участие в научном семинаре', 1, 3),
(1, 'Научные семинары', 'Участие в научном семинаре', 1, 4), -- Межвуз
(1, 'Научные семинары', 'Участие в научном семинаре', 2, 5),
(1, 'Научные семинары', 'Участие в научном семинаре', 3, 6), -- Областной
(1, 'Научные семинары', 'Участие в научном семинаре', 3, 7), -- Региональный
(1, 'Научные семинары', 'Участие в научном семинаре', 4, 8),
(1, 'Научные семинары', 'Участие в научном семинаре', 5, 9),

-- Публикации статей
(1, 'Публикации', 'Публикация в изданиях (ВАК)', 4, 10),
(1, 'Публикации', 'Публикация в зарубежных изданиях', 5, 10),
(1, 'Публикации', 'Публикация в изданиях', 4, 6), -- Всероссийские
(1, 'Публикации', 'Публикация в изданиях', 3, 5), -- Региональные
(1, 'Публикации', 'Публикация в изданиях', 2, 4), -- Городские
(1, 'Публикации', 'Публикация в изданиях', 1, 3), -- Вузовские

-- Изобретательская деятельность (Оставляем как есть, т.к. названия специфичны)
(1, 'Изобретательская деятельность', 'Участие в изобретательской деятельности', 1, 3),
(1, 'Изобретательская деятельность', 'Получение промышленного образца РФ', 4, 10),
(1, 'Изобретательская деятельность', 'Получение патента на изобретение', 4, 8),
(1, 'Изобретательская деятельность', 'Получение полезной модели', 4, 6),

-- Конкурсы научных работ (места)
(1, 'Конкурсы научных работ', 'Участие в конкурсе научных работ (проектов)', 1, 3),
(1, 'Конкурсы научных работ', 'Гран-при', 1, 6),
(1, 'Конкурсы научных работ', '1 место', 1, 5),
(1, 'Конкурсы научных работ', '2 место', 1, 4),
(1, 'Конкурсы научных работ', '3 место', 1, 3),
(1, 'Конкурсы научных работ', 'Специальная грамота', 1, 4),

-- Участие в выставках
(1, 'Выставки', 'Участие в выставке', 1, 3),
(1, 'Выставки', 'Участие в выставке', 1, 4), -- Межвуз
(1, 'Выставки', 'Участие в выставке', 2, 5),
(1, 'Выставки', 'Участие в выставке', 3, 6), -- Областная
(1, 'Выставки', 'Участие в выставке', 3, 7), -- Региональная
(1, 'Выставки', 'Участие в выставке', 4, 8),
(1, 'Выставки', 'Участие в выставке', 5, 9),

-- Призовые места на выставках
(1, 'Призовые места выставок', 'Гран-при', 1, 6),
(1, 'Призовые места выставок', '1 место', 1, 5),
(1, 'Призовые места выставок', '2 место', 1, 4),
(1, 'Призовые места выставок', '3 место', 1, 3),
(1, 'Призовые места выставок', 'Специальная грамота', 1, 4),

(1, 'Призовые места выставок', 'Гран-при', 2, 8),
(1, 'Призовые места выставок', '1 место', 2, 7),
(1, 'Призовые места выставок', '2 место', 2, 6),
(1, 'Призовые места выставок', '3 место', 2, 5),
(1, 'Призовые места выставок', 'Специальная грамота', 2, 6),

-- Прочая научная деятельность (Оставляем как есть)
(1, 'Прочая научная деятельность', 'Участие в написании заявки на научный грант', 1, 4),
(1, 'Прочая научная деятельность', 'Получение международной стипендии/премии', 5, 10),
(1, 'Прочая научная деятельность', 'Получение федеральной стипендии/премии', 4, 8),
(1, 'Прочая научная деятельность', 'Получение региональной стипендии/премии', 3, 6),
(1, 'Прочая научная деятельность', 'Член студенческого научно-технического общества (СНТО)', 1, 3);

-- ==========================================================
-- 2. Заполняем критерии для КУЛЬТУРНОЙ деятельности (category_id = 2)
-- Очищен description_text от указаний на уровень
-- ==========================================================
INSERT INTO Rating_Criteria (category_id, section_naming, description_text, level_type_id, points) VALUES

-- Культурно-массовая деятельность
(2, 'Участие в творчестве', 'Участник творческого коллектива СГТУ', 1, 3),

-- Участие в смотрах художественной самодеятельности
(2, 'Смотры художественной самодеятельности', 'Участие в смотрах художественной самодеятельности', 1, 3),
(2, 'Смотры художественной самодеятельности', 'Участие в смотрах художественной самодеятельности', 2, 4),
(2, 'Смотры художественной самодеятельности', 'Участие в смотрах художественной самодеятельности', 3, 5),
(2, 'Смотры художественной самодеятельности', 'Участие в смотрах художественной самодеятельности', 4, 6),
(2, 'Смотры художественной самодеятельности', 'Участие в смотрах художественной самодеятельности', 5, 7),

-- Призовые места на смотрах
(2, 'Призовые места смотров', 'Гран-при', 1, 5),
(2, 'Призовые места смотров', '1 место', 1, 4),
(2, 'Призовые места смотров', '2 место', 1, 3),
(2, 'Призовые места смотров', '3 место', 1, 2),
(2, 'Призовые места смотров', 'Специальная грамота', 1, 3),

(2, 'Призовые места смотров', 'Гран-при', 2, 6),
(2, 'Призовые места смотров', '1 место', 2, 5),
(2, 'Призовые места смотров', '2 место', 2, 4),
(2, 'Призовые места смотров', '3 место', 2, 3),
(2, 'Призовые места смотров', 'Специальная грамота', 2, 4),

(2, 'Призовые места смотров', 'Гран-при', 3, 7),
(2, 'Призовые места смотров', '1 место', 3, 6),
(2, 'Призовые места смотров', '2 место', 3, 5),
(2, 'Призовые места смотров', '3 место', 3, 4),
(2, 'Призовые места смотров', 'Специальная грамота', 3, 5),

(2, 'Призовые места смотров', 'Гран-при', 4, 9),
(2, 'Призовые места смотров', '1 место', 4, 8),
(2, 'Призовые места смотров', '2 место', 4, 7),
(2, 'Призовые места смотров', '3 место', 4, 6),
(2, 'Призовые места смотров', 'Специальная грамота', 4, 7),

(2, 'Призовые места смотров', 'Гран-при', 5, 10),
(2, 'Призовые места смотров', '1 место', 5, 9),
(2, 'Призовые места смотров', '2 место', 5, 8),
(2, 'Призовые места смотров', '3 место', 5, 7),
(2, 'Призовые места смотров', 'Специальная грамота', 5, 8),

-- Организация мероприятий (Оставляем как есть)
(2, 'Организация мероприятий', 'Участие в организации художественных выставок', 1, 3),
(2, 'Организация мероприятий', 'Участие в организации факультетских праздников', 1, 3);

-- ==========================================================
-- 3. Заполняем критерии для ОБЩЕСТВЕННОЙ деятельности (category_id = 3)
-- ИСПРАВЛЕН ID (было 4, стало 3) и ОЧИЩЕН description_text
-- ==========================================================
INSERT INTO Rating_Criteria (category_id, section_naming, description_text, level_type_id, points) VALUES

-- Волонтерство
(3, 'Волонтерство', 'Участник волонтерского движения', 1, 3), -- Факультет
(3, 'Волонтерство', 'Участник волонтерского движения', 1, 4), -- ВУЗ
(3, 'Волонтерство', 'Участник волонтерского движения', 2, 5),
(3, 'Волонтерство', 'Участник волонтерского движения', 3, 6),
(3, 'Волонтерство', 'Участник волонтерского движения', 4, 7),
(3, 'Волонтерство', 'Участник волонтерского движения', 5, 8),

-- Член профсоюзных объединений
(3, 'Профсоюзная деятельность', 'Член профсоюзных объединений', 1, 3),
(3, 'Профсоюзная деятельность', 'Член профсоюзных объединений', 1, 4),
(3, 'Профсоюзная деятельность', 'Член профсоюзных объединений', 2, 5),
(3, 'Профсоюзная деятельность', 'Член профсоюзных объединений', 3, 6),
(3, 'Профсоюзная деятельность', 'Член профсоюзных объединений', 4, 7),
(3, 'Профсоюзная деятельность', 'Член профсоюзных объединений', 5, 8),

-- Участие в волонтерских группах
(3, 'Волонтерские работы', 'Участие в волонтерских работах', 1, 3),
(3, 'Волонтерские работы', 'Участие в волонтерских работах', 1, 4), -- Межвуз
(3, 'Волонтерские работы', 'Участие в волонтерских работах', 2, 5),
(3, 'Волонтерские работы', 'Участие в волонтерских работах', 3, 6),
(3, 'Волонтерские работы', 'Участие в волонтерских работах', 4, 7),
(3, 'Волонтерские работы', 'Участие в волонтерских работах', 5, 8),

-- Участие в профориентационных мероприятиях
(3, 'Профориентация', 'Участие в профориентационных мероприятиях', 1, 3),
(3, 'Профориентация', 'Участие в профориентационных мероприятиях', 1, 4), -- ВУЗ
(3, 'Профориентация', 'Участие в профориентационных мероприятиях', 2, 5),
(3, 'Профориентация', 'Участие в профориентационных мероприятиях', 3, 6),
(3, 'Профориентация', 'Участие в профориентационных мероприятиях', 4, 7),
(3, 'Профориентация', 'Участие в профориентационных мероприятиях', 5, 8),

-- Редакторская деятельность (Оставляем как есть, это конкретные роли)
(3, 'Редакторская деятельность', 'Главный редактор факультетской стенгазеты', 1, 3),
(3, 'Редакторская деятельность', 'Член факультетской стенгазеты', 1, 3),
(3, 'Редакторская деятельность', 'Подготовка материалов для вузовских СМИ', 1, 3),

-- Общественные поручения (Оставляем как есть, это конкретные роли)
(3, 'Общественные поручения', 'Член студсовета общежития', 1, 5),
(3, 'Общественные поручения', 'Староста этажа общежития', 1, 6),
(3, 'Общественные поручения', 'Председатель студсовета общежития', 1, 10),

(3, 'Общественные поручения', 'Член Совета студентов и аспирантов (ССА)', 1, 5),
(3, 'Общественные поручения', 'Председатель Совета студентов и аспирантов (ССА)', 1, 10),

(3, 'Общественные поручения', 'Староста студенческой группы', 1, 6),
(3, 'Общественные поручения', 'Профорг студенческой группы', 1, 3),

(3, 'Общественные поручения', 'Культорганизатор факультета', 1, 10),
(3, 'Общественные поручения', 'Председатель профбюро факультета', 1, 9),
(3, 'Общественные поручения', 'Член профбюро факультета', 1, 6),

-- Посещение мероприятий
(3, 'Посещение мероприятий', 'Посещение мероприятий в составе группы', 1, 1), -- В рамках вуза
(3, 'Посещение мероприятий', 'Посещение мероприятий в составе группы', 1, 3); -- Вне вуза

-- ==========================================================
-- 4. Заполняем критерии для СПОРТИВНОЙ деятельности (category_id = 4)
-- ИСПРАВЛЕН ID (было 3, стало 4) и ОЧИЩЕН description_text
-- ==========================================================
INSERT INTO Rating_Criteria (category_id, section_naming, description_text, level_type_id, points) VALUES

-- Спортивно-оздоровительная деятельность (Оставляем как есть)
(4, 'Участие в спорте', 'Участник спортивной секции СГТУ', 1, 8),

-- Участие в спортивных соревнованиях
(4, 'Спортивные соревнования', 'Участие в соревнованиях', 1, 1),
(4, 'Спортивные соревнования', 'Участие в соревнованиях', 1, 8), -- Межвуз
(4, 'Спортивные соревнования', 'Участие в соревнованиях', 2, 3),
(4, 'Спортивные соревнования', 'Участие в соревнованиях', 3, 3),
(4, 'Спортивные соревнования', 'Участие в соревнованиях', 4, 25),
(4, 'Спортивные соревнования', 'Участие в соревнованиях', 5, 10),

-- Призовые места в спорте
(4, 'Призовые места в спорте', '1 место', 1, 4),
(4, 'Призовые места в спорте', '2 место', 1, 3),
(4, 'Призовые места в спорте', '3 место', 1, 2),

(4, 'Призовые места в спорте', '1 место', 2, 20),
(4, 'Призовые места в спорте', '2 место', 2, 15),
(4, 'Призовые места в спорте', '3 место', 2, 10),

(4, 'Призовые места в спорте', '1 место', 3, 20),
(4, 'Призовые места в спорте', '2 место', 3, 15),
(4, 'Призовые места в спорте', '3 место', 3, 10),

(4, 'Призовые места в спорте', '1 место', 4, 35),
(4, 'Призовые места в спорте', '2 место', 4, 20),
(4, 'Призовые места в спорте', '3 место', 4, 15),

(4, 'Призовые места в спорте', '1 место', 5, 40),
(4, 'Призовые места в спорте', '2 место', 5, 35),
(4, 'Призовые места в спорте', '3 место', 5, 25);

-- ==========================================================
-- Дополнительные INSERT-ы (Оставляем как есть, но с новыми ID)
-- ==========================================================
INSERT INTO Academic_Period (naming, start_date, end_date) VALUES
('семестр (Весна 2025)', '2025-02-01', '2025-06-30'),
('семестр (Осень 2025)', '2025-09-01', '2026-01-30');

-- 2. ДОСТИЖЕНИЯ СТУДЕНТОВ
-- Внимание: Здесь мы используем вложенные SELECT, чтобы точно попасть в нужные ID критериев,
-- так как после пересоздания таблиц ID могут сдвинуться.

INSERT INTO Student_Achievement (student_id, criteria_id, period_id, quantity, document_title, created_at) VALUES

-- === Студент 1 (Петров) ===

-- Наука: Участие в олимпиаде (ищем ID по тексту и категории)
(1, 
 (SELECT id FROM Rating_Criteria WHERE description_text LIKE 'Участие в предметных олимпиадах%' AND category_id=1 LIMIT 1), 
 2, 1, 'Сертификат участника', NOW()),

-- Культура: Участие в творческом коллективе
(1, 
 (SELECT id FROM Rating_Criteria WHERE description_text LIKE 'Участник творческого коллектива%' AND category_id=2 LIMIT 1), 
 2, 1, 'Справка из студклуба', NOW()),

-- Спорт: 1 место (ищем конкретно приз)
(1, 
 (SELECT id FROM Rating_Criteria WHERE description_text = '1 место' AND category_id=4 AND level_type_id=1 LIMIT 1), 
 2, 1, 'Грамота за победу в баскетболе', NOW()),


-- === Студент 2 (Соколова) ===

-- Общественная: Волонтер (ВУЗ)
(2, 
 (SELECT id FROM Rating_Criteria WHERE description_text = 'Участник волонтерского движения' AND category_id=3 AND level_type_id=1 LIMIT 1), 
 2, 1, 'Благодарственное письмо', NOW()),

-- Наука: Гран-при на конференции
(2, 
 (SELECT id FROM Rating_Criteria WHERE description_text = 'Гран-при' AND category_id=1 AND level_type_id=2 LIMIT 1), 
 2, 1, 'Диплом победителя', NOW()),


-- === Студент 3 (Орлов) ===

-- Спорт: Участие в соревнованиях
(3, 
 (SELECT id FROM Rating_Criteria WHERE description_text LIKE 'Участие в соревнованиях' AND category_id=4 AND level_type_id=2 LIMIT 1), 
 2, 1, 'Протокол соревнований', NOW()),

-- Культура: Организация праздников
(3, 
 (SELECT id FROM Rating_Criteria WHERE description_text LIKE 'Участие в организации факультетских%' AND category_id=2 LIMIT 1), 
 2, 1, 'Благодарность деканата', NOW());

-- 2. Получение ID новых студентов
SET @gromov_id = (SELECT id FROM Student WHERE email = 'gromov@uni.ru');
SET @zaytseva_id = (SELECT id FROM Student WHERE email = 'zaytseva@uni.ru');
SET @fedorov_id = (SELECT id FROM Student WHERE email = 'fedorov@uni.ru');
SET @current_period_id = 2; -- ID, который используется в существующих записях


-- 3. Добавление достижений

-- === Студент 4 (Громов, Курс 1) ===
-- Цель: Обойти Петрова в Спорте и Культуре
INSERT INTO Student_Achievement (student_id, criteria_id, period_id, quantity, document_title, created_at) VALUES 
-- Спорт: 1 место (Университетский, 4 балла)
(@gromov_id, 
 (SELECT id FROM Rating_Criteria WHERE description_text = '1 место' AND category_id=4 AND level_type_id=1 LIMIT 1), 
 @current_period_id, 1, 'Золотая медаль по баскетболу', NOW()),
 
-- Культура: 1 место (Университетский, 4 балла)
(@gromov_id, 
 (SELECT id FROM Rating_Criteria WHERE description_text = '1 место' AND category_id=2 AND level_type_id=1 LIMIT 1), 
 @current_period_id, 1, 'Диплом за танцевальный конкурс', NOW());


-- === Студент 5 (Зайцева, Курс 2) ===
-- Цель: Создать конкуренцию для Орлова в новых для него категориях (Наука, Общественная)
INSERT INTO Student_Achievement (student_id, criteria_id, period_id, quantity, document_title, created_at) VALUES 
-- Наука: 1 место (Университетский, 3 балла)
(@zaytseva_id, 
 (SELECT id FROM Rating_Criteria WHERE description_text = '1 место' AND category_id=1 AND level_type_id=1 LIMIT 1), 
 @current_period_id, 1, 'Диплом олимпиады по IT', NOW()),
 
-- Общественная: Член профсоюза (Университетский, 3 балла)
(@zaytseva_id, 
 (SELECT id FROM Rating_Criteria WHERE description_text = 'Член профсоюзных объединений' AND category_id=3 AND level_type_id=1 LIMIT 1), 
 @current_period_id, 1, 'Профсоюзный билет', NOW());


-- === Студент 6 (Федоров, Курс 3) ===
-- Цель: Быть единственным в Спорт-направлении на своем курсе
INSERT INTO Student_Achievement (student_id, criteria_id, period_id, quantity, document_title, created_at) VALUES 
-- Спорт: Участие в соревнованиях (Городской, 3 балла, 3 раза)
(@fedorov_id, 
 (SELECT id FROM Rating_Criteria WHERE description_text LIKE 'Участие в соревнованиях' AND category_id=4 AND level_type_id=2 LIMIT 1), 
 @current_period_id, 3, 'Протоколы всех соревнований', NOW());

-- Добавляем колонку типа достижения (если еще не добавлена выше)
-- Это нужно для корректной работы фильтров в JS
ALTER TABLE Rating_Criteria 
ADD COLUMN achievement_type VARCHAR(50) 
COMMENT 'Тип: participation (участие), prize (призовое место), other (другое)';

-- Обновляем типы для JS логики
UPDATE Rating_Criteria 
SET achievement_type = CASE 
    WHEN description_text LIKE '%участие%' OR description_text LIKE '%участник%' OR description_text LIKE '%член%' THEN 'participation'
    WHEN description_text LIKE '%место%' OR description_text LIKE '%гран-при%' OR description_text LIKE '%грамота%' THEN 'prize'
    ELSE 'other'
END;

DELIMITER //

-- Триггер предотвращает дублирование документов по названию
CREATE TRIGGER check_duplicate_document_before_insert
BEFORE INSERT ON Student_Achievement
FOR EACH ROW
BEGIN
    -- Проверяем, есть ли у этого студента документ с таким же названием
    -- Исключаем пустые названия, если они разрешены
    IF NEW.document_title IS NOT NULL AND NEW.document_title != '' THEN
        IF EXISTS (
            SELECT 1 
            FROM Student_Achievement 
            WHERE student_id = NEW.student_id 
            AND document_title = NEW.document_title
            -- Можно добавить AND period_id = NEW.period_id если названия могут повторяться в разных семестрах
        ) THEN
            SIGNAL SQLSTATE '45000' 
            SET MESSAGE_TEXT = 'Ошибка: Документ с таким названием уже загружен!';
        END IF;
    END IF;
END//

DELIMITER ;


DELIMITER //

-- Триггер для предотвращения вставки отрицательного числа
CREATE TRIGGER check_quantity_before_insert
BEFORE INSERT ON Student_Achievement
FOR EACH ROW
BEGIN
    IF NEW.quantity < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Ошибка: Количество достижений (quantity) не может быть отрицательным.';
    END IF;
END//

-- Триггер для предотвращения изменения на отрицательное число
CREATE TRIGGER check_quantity_before_update
BEFORE UPDATE ON Student_Achievement
FOR EACH ROW
BEGIN
    IF NEW.quantity < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Ошибка: Количество достижений (quantity) не может быть отрицательным.';
    END IF;
END//

DELIMITER ;


-- Процедура для вывода рейтинга по направлениям достижений
DELIMITER //

CREATE PROCEDURE GetCourseRatingAnalysis(
    IN studentId INT,
    IN periodId INT
)
BEGIN
    DECLARE my_course INT;

    -- 1. Узнаем курс студента
    SELECT sg.course INTO my_course
    FROM Student s
    JOIN Student_group sg ON s.student_group_id = sg.id
    WHERE s.id = studentId;

    -- 2. Выводим статистику по каждой категории
    SELECT 
        ac.naming AS category_name,
        ac.cod AS category_cod,
        
        -- Мои баллы в этой категории
        (SELECT COALESCE(SUM(rc.points * sa.quantity), 0)
         FROM Student_Achievement sa	
         JOIN Rating_Criteria rc ON sa.criteria_id = rc.id
         WHERE sa.student_id = studentId 
           AND sa.period_id = periodId 
           AND rc.category_id = ac.id
        ) as my_points,

        -- Мое место на курсе (считаем, у скольких людей баллов БОЛЬШЕ, чем у меня)
        (SELECT COUNT(*) + 1
         FROM (
             SELECT s_sub.id, SUM(rc_sub.points * sa_sub.quantity) as total_p
             FROM Student s_sub
             JOIN Student_group sg_sub ON s_sub.student_group_id = sg_sub.id
             JOIN Student_Achievement sa_sub ON s_sub.id = sa_sub.student_id
             JOIN Rating_Criteria rc_sub ON sa_sub.criteria_id = rc_sub.id
             WHERE sg_sub.course = my_course -- Тот же курс
               AND sa_sub.period_id = periodId
               AND rc_sub.category_id = ac.id -- Та же категория
             GROUP BY s_sub.id
         ) as competitors
         WHERE competitors.total_p > 
               (SELECT COALESCE(SUM(rc2.points * sa2.quantity), 0)
                FROM Student_Achievement sa2
                JOIN Rating_Criteria rc2 ON sa2.criteria_id = rc2.id
                WHERE sa2.student_id = studentId 
                  AND sa2.period_id = periodId 
                  AND rc2.category_id = ac.id)
        ) as my_rank,

        -- Всего участников в этой категории на курсе (конкуренция)
        (SELECT COUNT(DISTINCT sa_sub.student_id)
         FROM Student_Achievement sa_sub
         JOIN Student s_sub ON sa_sub.student_id = s_sub.id
         JOIN Student_group sg_sub ON s_sub.student_group_id = sg_sub.id
         JOIN Rating_Criteria rc_sub ON sa_sub.criteria_id = rc_sub.id
         WHERE sg_sub.course = my_course
           AND sa_sub.period_id = periodId
           AND rc_sub.category_id = ac.id
        ) as total_participants

    FROM Activity_Category ac;
END//

DELIMITER ;