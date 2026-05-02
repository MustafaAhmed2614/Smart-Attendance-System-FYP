import sqlite3

DB_PATH = "attendance.db"

def init_db():
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    # 1. Users Table (Login ke liye)
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            password TEXT NOT NULL,
            role TEXT NOT NULL
        )
    ''')

    # 🚀 2. UPDATED Students Table (Hybrid Flow ke liye face_status add kiya hai)
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS students (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            roll_number TEXT UNIQUE NOT NULL,
            face_status TEXT DEFAULT 'Pending'
        )
    ''')

    # 3. Courses Table (Teacher ke courses)
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS courses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            course_name TEXT,
            teacher_username TEXT
        )
    ''')

    # 4. Enrollments Table (Konsa student kis course mein hai)
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS enrollments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            roll_number TEXT,
            course_name TEXT
        )
    ''')

    # 5. UPDATED Attendance Logs (Course name aur auto timestamp ke sath)
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS attendance_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            student_name TEXT,
            status TEXT,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
            course_name TEXT  
        )
    ''')

    # 🚀 SPEED UPGRADES: Indexing lagana
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_roll ON students(roll_number)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_log_name ON attendance_logs(student_name)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_user ON users(username)')

    conn.commit()
    conn.close()

def get_db_connection():
    conn = sqlite3.connect(DB_PATH)
    # Is se data return karte waqt handle karna asaan hota hai
    conn.row_factory = sqlite3.Row 
    return conn