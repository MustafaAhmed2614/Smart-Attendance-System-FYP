from fastapi import APIRouter
import sqlite3
from datetime import date
from fastapi import UploadFile, File, Form, HTTPException
import os
import shutil
from fastapi.responses import FileResponse
from PIL import Image

router = APIRouter(
    prefix="/admin",
    tags=["Admin Dashboard"]
)

# Database connect karne ka helper function
def get_db_connection():
    conn = sqlite3.connect('attendance.db') 
    conn.row_factory = sqlite3.Row # Is se data dictionary format mein aata hai
    return conn

@router.get("/stats")
async def get_admin_stats():
    conn = get_db_connection()
    cursor = conn.cursor()

    try:
        cursor.execute("SELECT COUNT(*) as total_students FROM Students")
        total_students = cursor.fetchone()['total_students']

        today = date.today().strftime("%Y-%m-%d")
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
        query = """
            SELECT Students.roll_number, Students.name, Attendance.date, Attendance.time, Attendance.course_name 
            FROM Attendance 
            JOIN Students ON Attendance.roll_number = Students.roll_number 
            ORDER BY Attendance.date DESC, Attendance.time DESC
            LIMIT 100
        """
        cursor.execute(query)
        records = cursor.fetchall()

        reports_list = [dict(row) for row in records]

        return {
            "status": "success", 
            "total_records": len(reports_list),
            "data": reports_list
        }

    except Exception as e:
        return {"error": str(e)}
    finally:
        conn.close()

# 🚀 Added /students endpoint with image filename
@router.get("/students")
async def get_students():
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            SELECT name, roll_number, face_status, 
            (name || '_' || roll_number || '_front.jpg') as image_filename
            FROM students
        """)
        students = [dict(row) for row in cursor.fetchall()]
        return {"status": "Success", "students": students}
    except Exception as e:
        return {"error": str(e)}
    finally:
        conn.close()

# AI dataset ke liye folder create kar rahe hain
DATASET_DIR = "registered_faces"
os.makedirs(DATASET_DIR, exist_ok=True)

from PIL import Image

@router.post("/register-student")
async def register_student(
    roll_number: str = Form(...),
    name: str = Form(...),
    image: UploadFile = File(...)
):
    try:
        if not image:
            raise HTTPException(status_code=400, detail="No image uploaded.")

        STUDENTS_DIR = "students_pics"
        os.makedirs(STUDENTS_DIR, exist_ok=True)

        file_name = f"{name}_{roll_number}_front.jpg"
        file_path = os.path.join(STUDENTS_DIR, file_name)

        # 1. Image bytes save karein
        contents = await image.read()
        with open(file_path, "wb") as f:
            f.write(contents)

        # 🚀 2. Image Resize & Compression (Lag fix karne ke liye)
        try:
            img = Image.open(file_path)
            img = img.resize((300, 300), Image.Resampling.LANCZOS)
            img.save(file_path, optimize=True, quality=85)
        except Exception as img_err:
            print(f"Image optimization warning: {img_err}")

        # 3. Purana PKL cache delete karein taake AI naya face learn kar sakay
        for f in os.listdir(STUDENTS_DIR):
            if f.endswith(".pkl"):
                os.remove(os.path.join(STUDENTS_DIR, f))

        # 4. Database mein status update/insert karein
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
        cursor.execute("SELECT *, (name || '_' || roll_number || '_front.jpg') as image_filename FROM students WHERE roll_number = ?", (roll_number,))
        student = cursor.fetchone()
        
        if not student:
            return {"status": "error", "message": "Student not found"}

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

@router.get("/courses")
async def get_courses():
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT * FROM courses")
        courses = [dict(row) for row in cursor.fetchall()]
        return {"status": "success", "courses": courses}
    except Exception as e:
        return {"error": str(e)}
    finally:
        conn.close()

# 🚀 Updated to include image_filename for course students list
@router.get("/course-students/{course_name}")
async def get_course_students(course_name: str):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        query = """
            SELECT s.roll_number, s.name, s.face_status, 
            (s.name || '_' || s.roll_number || '_front.jpg') as image_filename
            FROM enrollments e
            JOIN students s ON e.roll_number = s.roll_number
            WHERE e.course_name = ?
        """
        cursor.execute(query, (course_name,))
        students = [dict(row) for row in cursor.fetchall()]
        return {"status": "success", "students": students}
    except Exception as e:
        return {"error": str(e)}
    finally:
        conn.close()

@router.get("/student-images/{file_name}")
async def get_student_image(file_name: str):
    IMAGE_DIR = "students_pics"
    file_path = os.path.join(IMAGE_DIR, file_name)

    if os.path.exists(file_path):
        return FileResponse(file_path)
    else:
        return {"error": "Image not found"}


@router.get("/defaulters")
async def get_defaulters():
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        # Har student ki total attendance count karna
        query = """
            SELECT s.roll_number, s.name, 
            (s.name || '_' || s.roll_number || '_front.jpg') as image_filename,
            COUNT(a.id) as attendance_count
            FROM students s
            LEFT JOIN attendance a ON s.roll_number = a.roll_number
            GROUP BY s.roll_number, s.name
        """
        cursor.execute(query)
        students = cursor.fetchall()
        
        # Misal ke tor par jin ki attendance 3 ya us se kam hai unhein defaulter consider karte hain (aap isay customize kar sakte hain)
        defaulters_list = []
        for row in students:
            student_dict = dict(row)
            # Aap yahan percentage ya minimum threshold set kar sakte hain
            if student_dict['attendance_count'] < 3: 
                defaulters_list.append(student_dict)

        return {"status": "success", "defaulters": defaulters_list}
    except Exception as e:
        return {"error": str(e)}
    finally:
        conn.close()