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
        # 1. Validation: Check karein ke file waqai image hai
        if not image.content_type.startswith("image/"):
            raise HTTPException(status_code=400, detail="Uploaded file must be an image.")

        # 2. File ka naam aur path set karein (e.g., registered_faces/FA20-001.jpg)
        file_extension = image.filename.split(".")[-1]
        file_name = f"{roll_number}.{file_extension}"
        file_path = os.path.join(DATASET_DIR, file_name)

        # 3. Image ko physical folder mein save karein
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(image.file, buffer)

        # 4. 🚀 Yahan Face Embedding ka function call hoga
        # face_embedding = generate_arcface_embedding(file_path)

        # 5. 🗄️ Yahan SQL Database ki Insert query aayegi
        # cursor.execute(
        #     "INSERT INTO students (roll_number, name, image_path) VALUES (?, ?, ?)", 
        #     (roll_number, name, file_path)
        # )
        # conn.commit()

        # Success message with data
        return {
            "status": "success", 
            "message": f"Student {name} ({roll_number}) registered successfully!",
            "saved_path": file_path
        }
        
    except Exception as e:
        return {"status": "error", "message": f"Registration failed: {str(e)}"}