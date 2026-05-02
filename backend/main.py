# main.py
from fastapi import FastAPI, File, UploadFile, Form
import os
import shutil
import uuid
import traceback 
from fastapi import Response
import csv                   
import io                     
# Clean Architecture imports
from db.database import init_db, get_db_connection
from services.ai_engine import recognize_faces
from pydantic import BaseModel
import sqlite3
app = FastAPI()

class UserSignup(BaseModel):
    username: str
    password: str
    role: str

class UserLogin(BaseModel):
    username: str
    password: str

class CourseCreate(BaseModel):
    course_name: str
    teacher_username: str



# System Start-up setup
init_db()
if not os.path.exists("./students_pics"):
    os.makedirs("./students_pics")

@app.get("/")
def read_root():
    return {"message": "FYP Smart Attendance API is Live! (Clean Architecture)"}

# 1. REGISTER STUDENT
@app.post("/register")
async def register_student(
    name: str = Form(...), 
    roll_number: str = Form(...),
    front_image: UploadFile = File(...),
    left_image: UploadFile = File(...),
    right_image: UploadFile = File(...)
):
    try:
        print(f"\n--- 📥 NEW REGISTRATION REQUEST: {name} ({roll_number}) ---")
        
        conn = get_db_connection()
        cursor = conn.cursor()
        try:
            cursor.execute("INSERT OR IGNORE INTO students (name, roll_number) VALUES (?, ?)", (name, roll_number))
            conn.commit()
        except Exception as db_err:
            print(f"DB Warning: {db_err}")
        finally:
            conn.close()

        files_to_save = {
            f"{name}_{roll_number}_front.jpg": front_image,
            f"{name}_{roll_number}_left.jpg": left_image,
            f"{name}_{roll_number}_right.jpg": right_image
        }

        for file_name, file_obj in files_to_save.items():
            file_path = os.path.join("./students_pics", file_name)
            print(f"📸 Saving photo to: {file_path}")
            with open(file_path, "wb") as buffer:
                shutil.copyfileobj(file_obj.file, buffer)
            
        print("🗑️ Deleting old PKL cache so AI learns new faces...")
        for f in os.listdir("./students_pics"):
            if f.endswith(".pkl"):
                os.remove(os.path.join("./students_pics", f))
                print(f"   -> Deleted: {f}")

        print(f"✅ REGISTRATION SUCCESSFUL FOR {name} with 3 Angles\n")
        return {"status": "Success", "message": f"3 Photos added for {name}!"}
    
    except Exception as e:
        print("\n‼️ ‼️ REGISTRATION ERROR ‼️ ‼️")
        traceback.print_exc() 
        print("‼️ ‼️ ‼️ ‼️ ‼️ ‼️ ‼️ ‼️ ‼️\n")
        return {"status": "Error", "message": str(e)}

# 2. DETECT ATTENDANCE
@app.post("/detect-attendance/")
async def detect_attendance(file: UploadFile = File(...)):
    unique_filename = f"temp_{uuid.uuid4()}.jpg"
    temp_file_path = unique_filename 
    
    try:
        with open(temp_file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        # 🚀 Calling the isolated AI Engine logic!
        final_names = recognize_faces(temp_file_path)

        if final_names:
            conn = get_db_connection()
            cursor = conn.cursor()
            for name in final_names:
                cursor.execute("INSERT INTO attendance_logs (student_name, status) VALUES (?, ?)", (name, "Present"))
            conn.commit()
            conn.close()

        if os.path.exists(temp_file_path):
            os.remove(temp_file_path)

        return {
            "status": "Success",
            "recognized_students": final_names,
            "message": f"Attendance marked for: {', '.join(final_names)}" if final_names else "No matching student found."
        }

    except Exception as e:
        if os.path.exists(temp_file_path):
            os.remove(temp_file_path)
        print(f"‼️ API ERROR: {str(e)}")
        return {"status": "Error", "recognized_students": [], "message": str(e)}

# 3. VIEW LOGS
@app.get("/view-attendance/")
def view_attendance():
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM attendance_logs ORDER BY timestamp DESC")
    logs = cursor.fetchall()
    conn.close()
    return {"logs": logs}

# 4. EXPORT ATTENDANCE TO EXCEL (CSV)
@app.get("/export-attendance/")
def export_attendance():
    try:
        # 1. Database se data nikalna
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT student_name, status, timestamp FROM attendance_logs ORDER BY timestamp DESC")
        logs = cursor.fetchall()
        conn.close()

        # 2. Memory mein ek CSV file banana
        stream = io.StringIO()
        writer = csv.writer(stream)

        # 3. Excel Sheet ke Columns ke naam likhna (Headers)
        writer.writerow(["Student Name", "Status", "Time"])

        # 4. Database ka saara data Excel sheet mein likhna
        for row in logs:
            writer.writerow(row)

        # 5. File ko download ke liye bhejna
        response = Response(content=stream.getvalue(), media_type="text/csv")
        response.headers["Content-Disposition"] = "attachment; filename=Attendance_Report.csv"
        
        return response

    except Exception as e:
        print(f"‼️ EXPORT ERROR: {str(e)}")
        return {"status": "Error", "message": str(e)}
    
# 5. CLEAR ATTENDANCE LOGS (Admin Only)
@app.delete("/clear-attendance/")
def clear_attendance():
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("DELETE FROM attendance_logs") # Sirf logs delete honge, students nahi
        conn.commit()
        conn.close()
        return {"status": "Success", "message": "Purani saari attendance clear ho gayi!"}
    except Exception as e:
        return {"status": "Error", "message": str(e)}
    
# ==========================================
# 🔐 AUTHENTICATION & STUDENT APIs
# ==========================================

# 6. SIGNUP API (Naya Account Banane ke liye)
@app.post("/signup/")
def signup(user: UserSignup):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        # Naya user database mein daalein
        cursor.execute(
            "INSERT INTO users (username, password, role) VALUES (?, ?, ?)",
            (user.username, user.password, user.role.lower())
        )
        conn.commit()
        conn.close()
        return {"status": "Success", "message": f"{user.role} account created for {user.username}"}
    except sqlite3.IntegrityError:
        return {"status": "Error", "message": "Username/Roll Number already exists!"}
    except Exception as e:
        return {"status": "Error", "message": str(e)}

# 7. LOGIN API (Account Check karne ke liye)
@app.post("/login/")
def login(user: UserLogin):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        # Database mein check karein ke is username aur password ka koi record hai?
        cursor.execute(
            "SELECT role FROM users WHERE username = ? AND password = ?",
            (user.username, user.password)
        )
        record = cursor.fetchone()
        conn.close()

        if record:
            return {"status": "Success", "role": record[0], "message": "Login Successful!"}
        else:
            return {"status": "Error", "message": "Invalid Username or Password"}
    except Exception as e:
        return {"status": "Error", "message": str(e)}

# 8. STUDENT ATTENDANCE API (Sirf apni attendance dekhne ke liye)
@app.get("/my-attendance/{roll_number}")
def get_my_attendance(roll_number: str):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Step 1: Sab se pehle Student ka naam dhoondein 'students' table se
        cursor.execute("SELECT name FROM students WHERE roll_number = ?", (roll_number,))
        student = cursor.fetchone()
        
        if not student:
            conn.close()
            return {"status": "Error", "message": "Student not found in database!"}
            
        # Agar db_connection mein row_factory lagi hai toh dictionary ki tarah use karein
        # Agar nahi lagi toh index [0] use karein. Hum dono handle kar lete hain:
        student_name = student["name"] if isinstance(student, sqlite3.Row) else student[0]
        
        # Step 2: Ab is naam se uski attendance history nikalein
        cursor.execute('''
            SELECT status, timestamp 
            FROM attendance_logs 
            WHERE student_name = ? 
            ORDER BY timestamp DESC
        ''', (student_name,))
        
        records = cursor.fetchall()
        conn.close()
        
        # Flutter ko bhejne ke liye list banayen
        formatted_logs = []
        for row in records:
            status = row["status"] if isinstance(row, sqlite3.Row) else row[0]
            timestamp = row["timestamp"] if isinstance(row, sqlite3.Row) else row[1]
            formatted_logs.append([status, timestamp])
            
        return {
            "status": "Success", 
            "student_name": student_name,  # <--- Yeh naam Flutter app ko jayega!
            "logs": formatted_logs
        }
        
    except Exception as e:
        return {"status": "Error", "message": str(e)}
    

# ==========================================
# 🚀 NAYI APIs COURSES KE LIYE
# ==========================================

# 1. Naya Course Banane ki API
@app.post("/add-course/")
def add_course(course: CourseCreate):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Course ko database mein save kar rahe hain
        cursor.execute(
            "INSERT INTO courses (course_name, teacher_username) VALUES (?, ?)",
            (course.course_name, course.teacher_username)
        )
        conn.commit()
        conn.close()
        
        return {"status": "Success", "message": f"Course '{course.course_name}' added successfully!"}
    except Exception as e:
        return {"status": "Error", "message": str(e)}


# 2. Teacher ke apne Courses mangwane ki API
@app.get("/my-courses/{teacher_username}")
def get_my_courses(teacher_username: str):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Sirf us teacher ke courses nikalo jo login hai
        cursor.execute(
            "SELECT course_name FROM courses WHERE teacher_username = ?", 
            (teacher_username,)
        )
        courses = cursor.fetchall()
        conn.close()
        
        # Database se nikal kar ek saaf list banayen
        course_list = []
        for row in courses:
            name = row["course_name"] if isinstance(row, sqlite3.Row) else row[0]
            course_list.append(name)
            
        return {"status": "Success", "courses": course_list}
    except Exception as e:
        return {"status": "Error", "message": str(e)}
    
# ==========================================
# 🚀 ADMIN API (Hybrid Flow)
# ==========================================

# Data aane ka format
class AdminStudentCreate(BaseModel):
    name: str
    roll_number: str
    course_name: str

@app.post("/admin/add-student/")
def admin_add_student(student: AdminStudentCreate):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # 1. Student ko database mein save karein 
        # (face_status khud-ba-khud 'Pending' save ho jayega database rule ke mutabiq)
        cursor.execute(
            "INSERT INTO students (name, roll_number) VALUES (?, ?)",
            (student.name, student.roll_number)
        )
        
        # 2. Student ko uske course mein enroll karein
        cursor.execute(
            "INSERT INTO enrollments (roll_number, course_name) VALUES (?, ?)",
            (student.roll_number, student.course_name)
        )
        
        conn.commit()
        conn.close()
        
        return {
            "status": "Success", 
            "message": f"Student {student.name} added successfully! Face registration is Pending."
        }
        
    except sqlite3.IntegrityError:
        # Agar roll number pehle se majood ho
        return {"status": "Error", "message": "This Roll Number already exists in the system!"}
    except Exception as e:
        return {"status": "Error", "message": str(e)}
    

# 3. Pending Students ki list mangwane ki API
@app.get("/pending-students/{course_name}")
def get_pending_students(course_name: str):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Enrollments aur Students table ko join kar ke 'Pending' bachon ka data nikalna
        cursor.execute('''
            SELECT s.name, s.roll_number 
            FROM students s
            JOIN enrollments e ON s.roll_number = e.roll_number
            WHERE e.course_name = ? AND s.face_status = 'Pending'
        ''', (course_name,))
        
        pending_students = cursor.fetchall()
        conn.close()
        
        # List ban banana taake Flutter ko asani se samajh aaye
        student_list = []
        for row in pending_students:
            student_list.append({
                "name": row["name"], 
                "roll_number": row["roll_number"]
            })
            
        return {"status": "Success", "pending_students": student_list}
    except Exception as e:
        return {"status": "Error", "message": str(e)}