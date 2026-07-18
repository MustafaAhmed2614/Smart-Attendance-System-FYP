from fastapi import APIRouter
import sqlite3
from datetime import date

router = APIRouter(
    prefix="/admin",
    tags=["Admin Dashboard"]
)

# Database connect karne ka helper function
def get_db_connection():
    # Aapke database file ka path (agar kisi aur folder mein hai toh path theek kar lein)
    conn = sqlite3.connect('attendance.db') 
    conn.row_factory = sqlite3.Row # Is se data dictionary format mein aata hai
    return conn

@router.get("/stats")
async def get_admin_stats():
    conn = get_db_connection()
    cursor = conn.cursor()

    try:
        # 1. Total Enrolled Students count karna
        cursor.execute("SELECT COUNT(*) as total_students FROM Students")
        total_students = cursor.fetchone()['total_students']

        # 2. Aaj kitne bache present hain wo count karna
        today = date.today().strftime("%Y-%m-%d")
        # Yahan date ka column name aapke DB ke hisaab se hoga
        cursor.execute("SELECT COUNT(DISTINCT roll_number) as present_today FROM Attendance WHERE date = ?", (today,))
        present_today = cursor.fetchone()['present_today']

        return {
            "total_students": total_students,
            "present_today": present_today,
            "date": today
        }

    except Exception as e:
        return {"error": str(e)}
    finally:
        conn.close()



@router.get("/reports")
async def get_attendance_reports():
    conn = get_db_connection()
    cursor = conn.cursor()

    try:
        # JOIN query: Students aur Attendance tables ko mila kar data nikalna
        query = """
            SELECT Students.roll_number, Students.name, Attendance.date, Attendance.time 
            FROM Attendance 
            JOIN Students ON Attendance.roll_number = Students.roll_number 
            ORDER BY Attendance.date DESC, Attendance.time DESC
            LIMIT 100
        """
        cursor.execute(query)
        records = cursor.fetchall()

        # Data ko JSON friendly format (list of dictionaries) mein convert karna
        reports_list = []
        for row in records:
            reports_list.append(dict(row))

        return {
            "status": "success", 
            "total_records": len(reports_list),
            "data": reports_list
        }

    except Exception as e:
        return {"error": str(e)}
    finally:
        conn.close()