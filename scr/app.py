from flask import Flask, render_template, session, request, redirect, url_for, flash, jsonify
import pymysql as db
from config import host, user, password, port, db_name

app = Flask(__name__)
app.secret_key = 'мой_секретный_ключ'

# Подключение к базе данных
def get_db_connection():
    """Получить соединение с БД"""
    try:
        connection = db.connect(
            host=host,
            port=port,
            user=user,
            password=password,
            database=db_name,
            cursorclass=db.cursors.DictCursor,
            autocommit=True
        )
        return connection
    except Exception as ex:
        print("Ошибка подключения к БД:", ex)
        return None

@app.route('/login', methods=['GET', 'POST'])
def login():
    """Страница входа"""
    if request.method == 'POST':
        email = request.form['email']
        password_input = request.form['password']
        
        conn = get_db_connection()
        if conn:
            try:
                with conn.cursor() as cursor:
                    # Проверяем логин и пароль
                    sql = """
                    SELECT s.*, sg.naming as group_name, sg.course, 
                            sp.title as specialty_name, sp.cod_specialty,
                            fs.title as form_study_name,
                            t.surname as tutor_surname, t.first_name as tutor_first_name, 
                            t.middle_name as tutor_middle_name
                    FROM Student s
                    JOIN Student_group sg ON s.student_group_id = sg.id
                    JOIN Specialty sp ON sg.specialty_id = sp.id
                    JOIN Form_study fs ON sg.form_study_id = fs.id
                    JOIN tutor t ON sg.tutor_id = t.id
                    WHERE s.email = %s AND s.student_password = %s
                    """
                    cursor.execute(sql, (email, password_input))
                    student = cursor.fetchone()
                    
                    if student:
                        # Сохраняем данные в сессии
                        session['student_id'] = student['id']
                        session['student_name'] = f"{student['surname']} {student['first_name']}"
                        session['student_email'] = student['email']
                        session['student_photo'] = student.get('profile_photo', '')
                        session['student_data'] = student
                        
                        flash('Вход выполнен успешно!', 'success')
                        return redirect(url_for('profile'))
                    else:
                        flash('Неверный email или пароль', 'error')
            except Exception as e:
                print("Ошибка при авторизации:", e)
                flash('Ошибка при входе в систему', 'error')
            finally:
                conn.close()
    
    return render_template('login.html')

@app.route('/logout')
def logout():
    """Выход из системы"""
    session.clear()
    flash('Вы вышли из системы', 'success')
    return redirect(url_for('login'))

@app.route('/')
def index():
    """Главная страница - перенаправление"""
    if 'student_id' in session:
        return redirect(url_for('profile'))
    return redirect(url_for('login'))

@app.route('/profile')
def profile():
    """Страница профиля"""
    if 'student_id' not in session:
        return redirect(url_for('login'))
    
    conn = get_db_connection()
    student = None
    
    if conn:
        try:
            with conn.cursor() as cursor:
                # Получаем данные студента
                sql = """
                SELECT s.*,
                        DATE_FORMAT(s.birth_date, '%%d.%%m.%%Y') as birth_date_str,
                        sg.naming as group_name, sg.course,
                        sp.title as specialty_name, sp.cod_specialty,
                        fs.title as form_study_name,
                        t.surname as tutor_surname, t.first_name as tutor_first_name,
                        t.middle_name as tutor_middle_name,
                        YEAR(s.created_at) as created_year,
                        YEAR(DATE_ADD(s.created_at, INTERVAL 4 YEAR)) as graduation_year
                FROM Student s
                JOIN Student_group sg ON s.student_group_id = sg.id
                JOIN Specialty sp ON sg.specialty_id = sp.id
                JOIN Form_study fs ON sg.form_study_id = fs.id
                JOIN tutor t ON sg.tutor_id = t.id
                WHERE s.id = %s
                """
                cursor.execute(sql, (session['student_id'],))
                student = cursor.fetchone()
                
                if not student:
                    flash('Данные студента не найдены', 'error')
                    return redirect(url_for('login'))
                
        except Exception as e:
            print("Ошибка при получении данных профиля:", e)
            flash('Ошибка при загрузке данных профиля', 'error')
        finally:
            conn.close()
    
    return render_template('profile.html', student=student)

@app.route('/update_profile', methods=['POST'])
def update_profile():
    """Обновление профиля с валидацией"""
    if 'student_id' not in session:
        return redirect(url_for('login'))
    
    email = request.form.get('email', '').strip()
    phone = request.form.get('phone', '').strip()
    address = request.form.get('address', '').strip()
    
    # Валидация email
    import re
    
    email_pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    if not re.match(email_pattern, email):
        flash('Email должен быть в формате example@domain.com', 'error')
        return redirect(url_for('profile'))
    
    # Валидация телефона (российский формат: +7XXXXXXXXXX)
    phone_pattern = r'^\+7\d{10}$'
    if not re.match(phone_pattern, phone):
        flash('Телефон должен быть в формате +7XXXXXXXXXX (10 цифр после +7)', 'error')
        return redirect(url_for('profile'))
    
    # Валидация адреса (минимум 5 символов, должен содержать улицу и дом)
    if len(address) < 5:
        flash('Адрес должен содержать не менее 5 символов', 'error')
        return redirect(url_for('profile'))
    
    if not any(word in address.lower() for word in ['ул.', 'улица', 'проспект', 'пр.', 'дом', 'д.']):
        flash('Адрес должен содержать указание на улицу и дом (например, "ул. Ленина, д. 10")', 'error')
        return redirect(url_for('profile'))
    
    conn = get_db_connection()
    if conn:
        try:
            with conn.cursor() as cursor:
                # Проверяем, не занят ли email другим пользователем
                check_sql = "SELECT id FROM Student WHERE email = %s AND id != %s"
                cursor.execute(check_sql, (email, session['student_id']))
                if cursor.fetchone():
                    flash('Этот email уже используется другим пользователем', 'error')
                    return redirect(url_for('profile'))
                
                # Проверяем, не занят ли телефон другим пользователем
                check_sql = "SELECT id FROM Student WHERE phone = %s AND id != %s"
                cursor.execute(check_sql, (phone, session['student_id']))
                if cursor.fetchone():
                    flash('Этот телефон уже используется другим пользователем', 'error')
                    return redirect(url_for('profile'))
                
                # Обновляем данные
                update_sql = """
                UPDATE Student 
                SET email = %s, phone = %s, address = %s 
                WHERE id = %s
                """
                cursor.execute(update_sql, (email, phone, address, session['student_id']))
                conn.commit()
                
                # Обновляем email в сессии
                session['student_email'] = email
                
                flash('Профиль успешно обновлен!', 'success')
                
        except Exception as e:
            print("Ошибка при обновлении профиля:", e)
            flash('Ошибка при обновлении профиля', 'error')
        finally:
            conn.close()
    
    return redirect(url_for('profile'))

@app.route('/update_password', methods=['POST'])
def update_password():
    """Обновление пароля"""
    if 'student_id' not in session:
        return redirect(url_for('login'))
    
    current_password = request.form.get('current_password', '')
    new_password = request.form.get('new_password', '')
    confirm_password = request.form.get('confirm_password', '')
    
    if new_password != confirm_password:
        flash('Новый пароль и подтверждение не совпадают', 'error')
        return redirect(url_for('profile'))
    
    conn = get_db_connection()
    if conn:
        try:
            with conn.cursor() as cursor:
                # Проверяем текущий пароль
                check_sql = "SELECT id FROM Student WHERE id = %s AND student_password = %s"
                cursor.execute(check_sql, (session['student_id'], current_password))
                if not cursor.fetchone():
                    flash('Текущий пароль неверен', 'error')
                    return redirect(url_for('profile'))
                
                # Обновляем пароль
                update_sql = "UPDATE Student SET student_password = %s WHERE id = %s"
                cursor.execute(update_sql, (new_password, session['student_id']))
                conn.commit()
                
                flash('Пароль успешно изменен!', 'success')
                
        except Exception as e:
            print("Ошибка при изменении пароля:", e)
            flash('Ошибка при изменении пароля', 'error')
        finally:
            conn.close()
    
    return redirect(url_for('profile'))

@app.route('/upload_photo', methods=['POST'])
def upload_photo():
    """Загрузка фото профиля с валидацией"""
    if 'student_id' not in session:
        return redirect(url_for('login'))
    
    photo_url = request.form.get('photo_url', '').strip()
    
    # Базовая валидация URL
    if not photo_url:
        flash('Пожалуйста, укажите URL фотографии', 'error')
        return redirect(url_for('profile'))
    
    # Проверяем, что URL заканчивается на расширение изображения
    valid_extensions = ('.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp')
    if not photo_url.lower().endswith(valid_extensions):
        flash('URL должен вести на изображение (jpg, png, gif, bmp, webp)', 'error')
        return redirect(url_for('profile'))
    
    # Проверяем формат URL
    if not (photo_url.startswith('http://') or photo_url.startswith('https://')):
        flash('URL должен начинаться с http:// или https://', 'error')
        return redirect(url_for('profile'))
    
    conn = get_db_connection()
    if conn:
        try:
            with conn.cursor() as cursor:
                update_sql = "UPDATE Student SET profile_photo = %s WHERE id = %s"
                cursor.execute(update_sql, (photo_url, session['student_id']))
                conn.commit()
                
                # Обновляем фото в сессии
                session['student_photo'] = photo_url
                
                flash('Фото профиля успешно обновлено!', 'success')
                
        except Exception as e:
            print("Ошибка при обновлении фото:", e)
            flash('Ошибка при обновлении фото профиля', 'error')
        finally:
            conn.close()
    
    return redirect(url_for('profile'))

@app.route('/notifications')
def notifications():
    """Страница уведомлений"""
    if 'student_id' not in session:
        return redirect(url_for('login'))
    return render_template('notifications.html')

@app.route('/messages')
def messages():
    """Страница сообщений"""
    if 'student_id' not in session:
        return redirect(url_for('login'))
    return render_template('messages.html')

@app.route('/grades')
def grades():
    """Страница успеваемости"""
    if 'student_id' not in session:
        return redirect(url_for('login'))
    return render_template('grades.html')

@app.route('/materials')
def materials():
    """Страница учебных материалов"""
    if 'student_id' not in session:
        return redirect(url_for('login'))
    return render_template('materials.html')

@app.route('/portfolio')
def portfolio():
    """Страница портфолио/рейтинга"""
    if 'student_id' not in session:
        return redirect(url_for('login'))
    
    student_id = session['student_id']
    student = session['student_data']

    conn = get_db_connection()
    data = {
        'categories': [],
        'total_points': 0,
        'achievements': [],
        'periods': [],
        'analysis': []
    }
    
    if conn:
        try:
            with conn.cursor() as cursor:
                # 1. Получаем все категории деятельности
                cursor.execute("SELECT id, naming, cod FROM Activity_Category")
                categories = cursor.fetchall()
                
                # 2. Получаем все доступные периоды (для истории)
                cursor.execute("SELECT id, naming FROM Academic_Period ORDER BY start_date DESC")
                data['periods'] = cursor.fetchall()

                # --- НОВОЕ: ОПРЕДЕЛЯЕМ ТЕКУЩИЙ СЕМЕСТР ---
                # Ищем семестр, который идет сейчас (по дате)
                cursor.execute("SELECT id, naming FROM Academic_Period WHERE end_date >= CURDATE() ORDER BY start_date LIMIT 1")
                current_period = cursor.fetchone()
                
                # Если текущего нет (каникулы), берем самый последний из добавленных
                if not current_period and data['periods']:
                    current_period = data['periods'][0]
                
                data['current_period'] = current_period
                # ----------------------------------------

                # 3. Для каждой категории получаем достижения студента
                for category in categories:
                    # Используем ID текущего семестра, если он найден, иначе None
                    period_filter_id = current_period['id'] if current_period else 0

                    # Баллы по категории за ТЕКУЩИЙ семестр
                    sql = """
                    SELECT rc.section_naming, rc.description_text, lt.title as level, 
                           rc.points, sa.quantity, (rc.points * sa.quantity) as total,
                            sa.created_at, sa.document_title
                    FROM Student_Achievement sa
                    JOIN Rating_Criteria rc ON sa.criteria_id = rc.id
                    JOIN level_type lt ON rc.level_type_id = lt.id
                    WHERE sa.student_id = %s AND rc.category_id = %s 
                    AND sa.period_id = %s  -- Фильтр по текущему семестру
                    """
                    cursor.execute(sql, (student_id, category['id'], period_filter_id))
                    achievements = cursor.fetchall()
                    
                    # Сумма баллов по категории (за текущий семестр)
                    points_sql = """
                    SELECT SUM(rc.points * sa.quantity) as category_total
                    FROM Student_Achievement sa
                    JOIN Rating_Criteria rc ON sa.criteria_id = rc.id
                    WHERE sa.student_id = %s AND rc.category_id = %s
                    AND sa.period_id = %s
                    """
                    cursor.execute(points_sql, (student_id, category['id'], period_filter_id))
                    points_result = cursor.fetchone()
                    category_total = points_result['category_total'] or 0
                    
                    count_sql = """
                    SELECT SUM(sa.quantity) as total_count
                    FROM Student_Achievement sa
                    JOIN Rating_Criteria rc ON sa.criteria_id = rc.id
                    WHERE sa.student_id = %s AND rc.category_id = %s 
                    AND sa.period_id = %s
                    """
                    cursor.execute(count_sql, (student_id, category['id'], period_filter_id))
                    count_result = cursor.fetchone()
                    total_count = count_result['total_count'] or 0

                    data['categories'].append({
                        'id': category['id'],
                        'name': category['naming'],
                        'cod': category['cod'],
                        'points': category_total,
                        'achievements': achievements,
                        'total_count': total_count
                    })
                    data['total_points'] += category_total
                
                # 4. Получаем последние достижения для отображения (история)
                cursor.execute("""
                    SELECT sa.*, rc.description_text, rc.points, ac.naming as category_name,
                            ap.naming as period_name, lt.title as level_title
                    FROM Student_Achievement sa
                    JOIN Rating_Criteria rc ON sa.criteria_id = rc.id
                    JOIN Activity_Category ac ON rc.category_id = ac.id
                    JOIN Academic_Period ap ON sa.period_id = ap.id
                    JOIN level_type lt ON rc.level_type_id = lt.id
                    WHERE sa.student_id = %s
                    ORDER BY sa.created_at DESC
                """, (student_id,))
                data['recent_achievements'] = cursor.fetchall()
                
                # 5. Анализ конкуренции
                if current_period:
                    cursor.callproc('GetCourseRatingAnalysis', (student_id, current_period['id']))
                    data['analysis'] = cursor.fetchall()

        except Exception as e:
            # ... (остальной код ошибки без изменений)
            print("Ошибка при получении данных портфолио:", e)
            flash('Ошибка при загрузке данных рейтинга', 'error')
        finally:
            conn.close()
    
    return render_template('portfolio.html', data=data, student=student)

@app.route('/add_achievement', methods=['POST'])
def add_achievement():
    """Добавление достижения"""
    if 'student_id' not in session:
        return redirect(url_for('login'))
    
    # Получаем данные из формы
    criteria_id = request.form.get('criteria_id')
    quantity = request.form.get('quantity', 1)
    document_title = request.form.get('document_title', '')
    period_id = request.form.get('period_id')
    
    conn = get_db_connection()
    if conn:
        try:
            with conn.cursor() as cursor:
                sql = """
                INSERT INTO Student_Achievement
                (student_id, criteria_id, period_id, quantity, document_title, created_at)
                VALUES (%s, %s, %s, %s, %s, NOW())
                """
                cursor.execute(sql, (
                    session['student_id'], 
                    criteria_id, 
                    period_id, 
                    quantity, 
                    document_title
                ))
                conn.commit()
                
                flash('Достижение успешно добавлено!', 'success')
                
        except Exception as e:
            # Если это наша ошибка из триггера, текст будет внутри e
            error_msg = str(e)
            if "Документ с таким названием уже загружен" in error_msg:
                flash('Ошибка: Такой документ уже существует!', 'error')
            else:
                print("Ошибка при добавлении достижения:", e)
                flash('Ошибка при добавлении достижения', 'error')
        finally:
            conn.close()
    
    return redirect(url_for('portfolio'))

@app.route('/delete_achievement/<int:achievement_id>')
def delete_achievement(achievement_id):
    """Удаление достижения"""
    if 'student_id' not in session:
        return redirect(url_for('login'))
    
    conn = get_db_connection()
    if conn:
        try:
            with conn.cursor() as cursor:
                # Проверяем, что достижение принадлежит студенту
                check_sql = "SELECT id FROM Student_Achievement WHERE id = %s AND student_id = %s"
                cursor.execute(check_sql, (achievement_id, session['student_id']))
                if cursor.fetchone():
                    delete_sql = """
                    DELETE
                    FROM Student_Achievement
                    WHERE id = %s"""

                    cursor.execute(delete_sql, (achievement_id,))
                    conn.commit()
                    flash('Достижение удалено', 'success')
                else:
                    flash('Достижение не найдено или недоступно', 'error')
                    
        except Exception as e:
            print("Ошибка при удалении достижения:", e)
            flash('Ошибка при удалении достижения', 'error')
        finally:
            conn.close()
    
    return redirect(url_for('portfolio'))

@app.route('/get_criteria/<category_cod>')
def get_criteria(category_cod):
    """Получение критериев для категории (для AJAX)"""
    conn = get_db_connection()
    criteria = []
    
    if conn:
        try:
            with conn.cursor() as cursor:
                sql = """
                SELECT rc.id, rc.section_naming, rc.description_text, 
                        lt.title as level, rc.points
                FROM Rating_Criteria rc
                JOIN Activity_Category ac ON rc.category_id = ac.id
                JOIN level_type lt ON rc.level_type_id = lt.id
                WHERE ac.cod = %s
                ORDER BY rc.section_naming, rc.points DESC
                """
                cursor.execute(sql, (category_cod,))
                criteria = cursor.fetchall()
        except Exception as e:
            print("Ошибка при получении критериев:", e)
        finally:
            conn.close()

    return jsonify(criteria)

@app.route('/get_criteria_data/<category_cod>')
def get_criteria_data(category_cod):
    """Получение структурированных данных по критериям"""
    conn = get_db_connection()
    data = {
        'sections': {},
        'levels': {}
    }
    
    if conn:
        try:
            with conn.cursor() as cursor:
                # 1. Получаем все критерии для категории
                sql = """
                SELECT rc.id, rc.section_naming, rc.description_text, 
                        rc.level_type_id, rc.points, rc.achievement_type,
                        lt.title as level_title
                FROM Rating_Criteria rc
                JOIN Activity_Category ac ON rc.category_id = ac.id
                JOIN level_type lt ON rc.level_type_id = lt.id
                WHERE ac.cod = %s
                ORDER BY rc.section_naming, rc.points DESC
                """
                cursor.execute(sql, (category_cod,))
                criteria_list = cursor.fetchall()
                
                # Структурируем по ID
                for criteria in criteria_list:
                    data['sections'][criteria['id']] = {
                        'id': criteria['id'],
                        'section_naming': criteria['section_naming'],
                        'description_text': criteria['description_text'],
                        'level_type_id': criteria['level_type_id'],
                        'points': criteria['points'],
                        'achievement_type': criteria.get('achievement_type', 'other'),
                        'level_title': criteria['level_title']
                    }
                
                # 2. Получаем все уровни
                cursor.execute("SELECT id, title FROM level_type ORDER BY id")
                levels = cursor.fetchall()
                for level in levels:
                    data['levels'][level['id']] = {
                        'id': level['id'],
                        'title': level['title']
                    }
                
        except Exception as e:
            print("Ошибка при получении структурированных данных:", e)
            return jsonify({'error': str(e)}), 500
        finally:
            conn.close()
    
    return jsonify(data)

@app.route('/filter_achievements')
def filter_achievements():
    """API для фильтрации достижений (AJAX)"""
    if 'student_id' not in session:
        return jsonify({'error': 'Unauthorized'}), 401

    student_id = session['student_id']
    period_id = request.args.get('period_id')
    category_cod = request.args.get('category_cod')

    conn = get_db_connection()
    achievements = []
    
    if conn:
        try:
            with conn.cursor() as cursor:
                # Базовый SQL запрос
                sql = """
                    SELECT sa.id, sa.quantity, sa.created_at, sa.document_title,
                            rc.description_text, rc.points,
                            ac.naming as category_name, ac.cod as category_cod,
                            lt.title as level_title
                    FROM Student_Achievement sa
                    JOIN Rating_Criteria rc ON sa.criteria_id = rc.id
                    JOIN Activity_Category ac ON rc.category_id = ac.id
                    JOIN level_type lt ON rc.level_type_id = lt.id
                    WHERE sa.student_id = %s
                """
                params = [student_id]

                # Динамически добавляем условия фильтрации
                if period_id:
                    sql += " AND sa.period_id = %s"
                    params.append(period_id)
                
                if category_cod:
                    sql += " AND ac.cod = %s"
                    params.append(category_cod)

                sql += " ORDER BY sa.created_at DESC"

                cursor.execute(sql, tuple(params))
                raw_data = cursor.fetchall()
                
                # Преобразуем дату в строку для JSON
                for item in raw_data:
                    item['created_at'] = item['created_at'].strftime('%d.%m.%Y')
                    achievements.append(item)

        except Exception as e:
            print("Ошибка фильтрации:", e)
        finally:
            conn.close()

    return jsonify(achievements)

@app.route('/decanat')
def decanat():
    """Страница онлайн-деканата"""
    if 'student_id' not in session:
        return redirect(url_for('login'))
    return render_template('decanat.html')

@app.route('/stipendii')
def stipendii():
    """Страница стипендий"""
    if 'student_id' not in session:
        return redirect(url_for('login'))
    return render_template('stipendii.html')

if __name__ == '__main__':
    app.run(debug=True)