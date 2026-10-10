from fastapi import APIRouter
import sqlite3
from datetime import date
from fastapi import UploadFile, File, Form
import os
import shutil

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
        # Yahan Attendance.course_name ko query mein shamil kar diya gaya hai
        query = """
            SELECT Students.roll_number, Students.name, Attendance.date, Attendance.time, Attendance.course_name 
            FROM Attendance 
            JOIN Students ON Attendance.roll_number = Students.roll_number 
            ORDER BY Attendance.date DESC, Attendance.time DESC
            LIMIT 100
        """
        cursor.execute(query)
        records = cursor.fetchall()

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





# AI dataset ke liye folder create kar rahe hain
DATASET_DIR = "registered_faces"
os.makedirs(DATASET_DIR, exist_ok=True)

@router.post("/register-student")
async def register_student(
    roll_number: str = Form(...),
    name: str = Form(...),
    image: UploadFile = File(...)
):
    try:
        # 1. Check if file is provided
        if not image:
            raise HTTPException(status_code=400, detail="No image uploaded.")

        # 2. Path set karein jahan AI engine read karta hai (students_pics folder)
        STUDENTS_DIR = "students_pics"
        os.makedirs(STUDENTS_DIR, exist_ok=True)

        # 3. File ka naam format karein (e.g., Name_Roll_front.jpg)
        file_name = f"{name}_{roll_number}_front.jpg"
        file_path = os.path.join(STUDENTS_DIR, file_name)

        # 4. Image bytes save karein
        contents = await image.read()
        with open(file_path, "wb") as f:
            f.write(contents)

        # 5. Purana PKL cache delete karein taake AI naya face learn kar sakay
        for f in os.listdir(STUDENTS_DIR):
            if f.endswith(".pkl"):
                os.remove(os.path.join(STUDENTS_DIR, f))

        # 6. Database mein face status update ya insert karein
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM students WHERE roll_number = ?", (roll_number,))
        if cursor.fetchone():
            cursor.execute(
                "UPDATE students SET name = ?, face_status = 'Registered' WHERE roll_number = ?",
                (name, roll_number)
            )
        else:
            cursor.execute(
                "INSERT INTO students (name, roll_number, face_status) VALUES (?, ?, 'Registered')",
                (name, roll_number)
            )
        conn.commit()
        conn.close()

        return {
            "status": "success", 
            "message": f"Student {name} registered successfully!",
            "saved_path": file_path
        }
        
    except Exception as e:
        return {"status": "error", "message": f"Registration failed: {str(e)}"}




@router.get("/student-detail/{roll_number}")
async def get_student_detail(roll_number: str):
    conn = get_db_connection()
    cursor = conn.cursor()

    try:
        # 1. Student ki basic info lena
        cursor.execute("SELECT * FROM students WHERE roll_number = ?", (roll_number,))
        student = cursor.fetchone()
        
        if not student:
            return {"status": "error", "message": "Student not found"}

        # 2. Us student ki attendance history lena
        cursor.execute("""
            SELECT date, time, course_name 
            FROM attendance 
            WHERE roll_number = ? 
            ORDER BY date DESC, time DESC
        """, (roll_number,))
        attendance_logs = cursor.fetchall()

        logs_list = [dict(row) for row in attendance_logs]

        return {
            "status": "success",
            "student": dict(student),
            "total_attendance": len(logs_list),
            "logs": logs_list
        }

    except Exception as e:
        return {"status": "error", "message": str(e)}
    finally:
        conn.close()