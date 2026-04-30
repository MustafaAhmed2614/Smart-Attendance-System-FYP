import sqlite3

DB_PATH = "attendance.db"

def init_db():
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    # 1. Students Table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS students (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            roll_number TEXT UNIQUE NOT NULL
        )
    ''')
    
    # 2. Attendance Logs Table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS attendance_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            student_name TEXT,
            status TEXT,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    # 3. Users Table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            password TEXT NOT NULL,
            role TEXT NOT NULL 
        )
    ''')

    # 🚀 SPEED UPGRADES: Indexing lagana
    # Roll number aur Student name par index lagane se search instant ho jati hai
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