import os
import csv
import io
import shutil
import uuid
import sqlite3
import traceback
import base64
from datetime import datetime, timedelta

import cv2
import numpy as np
from fastapi import FastAPI, HTTPException, File, UploadFile, Form, Response
from fastapi.middleware.cors import CORSMiddleware
from passlib.context import CryptContext
from pydantic import BaseModel

# Clean Architecture imports
from db.database import init_db, get_db_connection
from services.ai_engine import recognize_faces
from routers import admin

# Initialize App & Middleware
app = FastAPI(title="Smart Attendance AI Engine")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(admin.router)

# Initialize Database & Directories
init_db()
os.makedirs("./students_pics", exist_ok=True)
ATTENDANCE_IMG_DIR = "attendance_photos"
os.makedirs(ATTENDANCE_IMG_DIR, exist_ok=True)

# Password Hashing Setup
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def get_password_hash(password):
    return pwd_context.hash(password)

def verify_password(plain_password, hashed_password):
    return pwd_context.verify(plain_password, hashed_password)

# Pydantic Models
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

class AdminStudentCreate(BaseModel):
    name: str
    roll_number: str
    course_name: str


# ==========================================
# GENERAL & ROOT ENDPOINTS
# ==========================================

@app.get("/")
def read_root():
    return {"message": "Smart Attendance AI Engine is Live!"}


# ==========================================
# STUDENT REGISTRATION & ATTENDANCE ENDPOINTS
# ==========================================

@app.post("/register")
async def register_student(
    name: str = Form(...), 
    roll_number: str = Form(...),
    front_image: UploadFile = File(...),
    left_image: UploadFile = File(...),
    right_image: UploadFile = File(...),
    up_image: UploadFile = File(...),
    smile_image: UploadFile = File(...)
):
    try:
        print(f"\n--- 📥 NEW FACE REGISTRATION: {name} ({roll_number}) ---")
        os.makedirs("./students_pics", exist_ok=True)
        files_to_save = {
            f"{name}_{roll_number}_front.jpg": front_image,
            f"{name}_{roll_number}_left.jpg": left_image,
            f"{name}_{roll_number}_right.jpg": right_image,
            f"{name}_{roll_number}_up.jpg": up_image,
            f"{name}_{roll_number}_smile.jpg": smile_image
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
                
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            "UPDATE students SET face_status = 'Registered' WHERE roll_number = ?", 
            (roll_number,)
        )
        conn.commit()
        conn.close()

        print(f"✅ REGISTRATION SUCCESSFUL FOR {name}\n")
        return {"status": "Success", "message": f"Face Registered for {name}!"}
    
    except Exception as e:
        print("\n‼️ ‼️ REGISTRATION ERROR ‼️ ‼️")
        traceback.print_exc() 
        return {"status": "Error", "message": str(e)}


@app.post("/detect-attendance/")
async def detect_attendance(
    file: UploadFile = File(...), 
    course_name: str = Form(...)
):
    clean_course_name = course_name.strip()
    current_time = datetime.now()
    timestamp = current_time.strftime("%Y-%m-%d_%H-%M-%S")
    today_date = current_time.strftime("%Y-%m-%d")
    time_now = current_time.strftime("%H:%M:%S")
    filename = f"{clean_course_name}_{timestamp}.jpg"
    file_path = os.path.join(ATTENDANCE_IMG_DIR, filename) 
    
    try:
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
        final_names = recognize_faces(file_path)

        img_base64 = None 

        if final_names:
            conn = get_db_connection()
            cursor = conn.cursor()
            valid_students_marked = []
            
            for name in final_names:
                cursor.execute('''
                    SELECT s.roll_number 
                    FROM students s
                    JOIN enrollments e ON s.roll_number = e.roll_number
                    WHERE s.name = ? AND TRIM(e.course_name) = ?
                ''', (name, clean_course_name))
                
                student_row = cursor.fetchone()
                
                if student_row:
                    roll_no = student_row["roll_number"]
                    valid_students_marked.append(name) 
                    cursor.execute('''
                        SELECT id FROM attendance 
                        WHERE roll_number = ? AND TRIM(course_name) = ? AND date = ?
                    ''', (roll_no, clean_course_name, today_date))
                    
                    exists = cursor.fetchone()
                    
                    if not exists:
                        cursor.execute(
                            "INSERT INTO attendance (roll_number, course_name, date, time) VALUES (?, ?, ?, ?)", 
                            (roll_no, clean_course_name, today_date, time_now)
                        )
                        cursor.execute(
                            "INSERT INTO attendance_logs (student_name, status, course_name) VALUES (?, ?, ?)", 
                            (name, "Present", clean_course_name)
                        )
                        print(f"✅ Marked {name} ({roll_no}) in {clean_course_name}")
                else:
                    print(f"⚠️ Ignored '{name}': Recognized by AI but NOT enrolled in {clean_course_name}")

            conn.commit()
            conn.close()

            image = cv2.imread(file_path)
            y_position = 30
            for name in valid_students_marked:
                cv2.putText(image, f"Identified: {name}", (20, y_position), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 255, 0), 2)
                y_position += 30 
                
            _, buffer = cv2.imencode('.jpg', image)
            img_base64 = base64.b64encode(buffer).decode('utf-8')

        return_list = valid_students_marked if final_names else []

        return {
            "status": "Success",
            "recognized_students": return_list,
            "image": img_base64,
            "message": f"Attendance marked for: {', '.join(return_list)}" if return_list else "No enrolled student recognized."
        }

    except Exception as e:
        if os.path.exists(file_path):
            os.remove(file_path)
        print(f"‼️ API ERROR: {str(e)}")
        return {"status": "Error", "recognized_students": [], "message": str(e)}    


@app.get("/view-attendance/")
def view_attendance():
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM attendance_logs ORDER BY timestamp DESC")
    logs = cursor.fetchall()
    conn.close()
    return {"logs": logs}


@app.get("/daily-attendance/{course_name}")
async def get_daily_attendance(course_name: str):
    try:
        clean_course = course_name.strip()
        conn = get_db_connection()
        cursor = conn.cursor()
        
        today = datetime.now().strftime("%Y-%m-%d")
        cursor.execute('''
            SELECT s.name, s.roll_number 
            FROM students s
            JOIN enrollments e ON s.roll_number = e.roll_number
            WHERE TRIM(e.course_name) = ? AND s.face_status = 'Registered'
        ''', (clean_course,))
        all_students = cursor.fetchall()
        
        cursor.execute('''
            SELECT roll_number FROM attendance 
            WHERE TRIM(course_name) = ? AND date = ?
        ''', (clean_course, today))
        
        present_rolls = [row["roll_number"] for row in cursor.fetchall()]
        conn.close()
        
        attendance_list = []
        for student in all_students:
            status = "Present" if student["roll_number"] in present_rolls else "Absent"
            attendance_list.append({
                "name": student["name"],
                "roll_number": student["roll_number"],
                "status": status
            })
            
        return {
            "status": "Success", 
            "date": today, 
            "attendance_list": attendance_list
        }
        
    except Exception as e:
        return {"status": "Error", "message": str(e)}


@app.get("/export-attendance/")
def export_attendance():
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT student_name, status, timestamp FROM attendance_logs ORDER BY timestamp DESC")
        logs = cursor.fetchall()
        conn.close()

        stream = io.StringIO()
        writer = csv.writer(stream)
        writer.writerow(["Student Name", "Status", "Time"])

        for row in logs:
            writer.writerow(row)

        response = Response(content=stream.getvalue(), media_type="text/csv")
        response.headers["Content-Disposition"] = "attachment; filename=Attendance_Report.csv"
        return response

    except Exception as e:
        return {"status": "Error", "message": str(e)}


@app.delete("/clear-attendance/")
def clear_attendance():
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("DELETE FROM attendance_logs")
        conn.commit()
        conn.close()
        return {"status": "Success", "message": "Attendance logs cleared successfully!"}
    except Exception as e:
        return {"status": "Error", "message": str(e)}


# ==========================================
# AUTHENTICATION & COURSES
# ==========================================

@app.post("/signup/")
async def signup(user: dict): 
    username = user.get("username")
    raw_password = user.get("password")
    role = user.get("role")
    hashed_password = get_password_hash(raw_password)
    
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            "INSERT INTO users (username, password, role) VALUES (?, ?, ?)",
            (username, hashed_password, role) 
        )
        conn.commit()
        return {"status": "Success", "message": "Account created securely!"}
    except Exception:
        return {"status": "Error", "message": "Username already exists!"}
    finally:
        conn.close()


@app.post("/login/")
async def login(user: dict):
    username = user.get("username")
    raw_password = user.get("password")
    role = user.get("role")
    
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT password, role FROM users WHERE username = ?", (username,))
    db_user = cursor.fetchone()
    conn.close()

    if not db_user:
        return {"status": "Error", "message": "User not found!"}

    db_hashed_password = db_user["password"]
    db_role = db_user["role"]

    if not verify_password(raw_password, db_hashed_password):
        return {"status": "Error", "message": "Incorrect password!"}
        
    if role != db_role:
        return {"status": "Error", "message": "Incorrect role selected!"}

    return {"status": "Success", "message": "Login successful!"}


@app.get("/my-attendance/{roll_number}")
def get_my_attendance(roll_number: str):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT name FROM students WHERE roll_number = ?", (roll_number,))
        student = cursor.fetchone()
        
        if not student:
            conn.close()
            return {"status": "Error", "message": "Student not found!"}
            
        student_name = student[0]
        cursor.execute("SELECT TRIM(course_name) FROM enrollments WHERE roll_number = ?", (roll_number,))
        enrolled_courses = [row[0] for row in cursor.fetchall()]

        if not enrolled_courses:
            conn.close()
            return {"status": "Success", "student_name": student_name, "attendance_data": []}

        placeholders = ','.join(['?'] * len(enrolled_courses))
        query = f'''
            SELECT status, timestamp, course_name 
            FROM attendance_logs 
            WHERE student_name = ? AND TRIM(course_name) IN ({placeholders}) 
            ORDER BY timestamp DESC
        '''
        
        params = [student_name] + enrolled_courses
        cursor.execute(query, params)
        records = cursor.fetchall()
        conn.close()

        grouped_data = {}
        for row in records:
            status = row[0]
            timestamp_str = row[1]
            raw_course_name = row[2] if row[2] else "Unknown Course"
            course_name = raw_course_name.strip() 
            date_only = timestamp_str[:10]
            
            if course_name not in grouped_data:
                grouped_data[course_name] = {}
                
            if date_only not in grouped_data[course_name]:
                grouped_data[course_name][date_only] = {
                    "status": status,
                    "date": timestamp_str
                }
                
        final_output = [
            {"course_name": course, "records": list(dates.values())}
            for course, dates in grouped_data.items()
        ]

        return {"status": "Success", "student_name": student_name, "attendance_data": final_output}
        
    except Exception as e:
        return {"status": "Error", "message": str(e)}


@app.post("/add-course/")
def add_course(course: CourseCreate):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            "INSERT INTO courses (course_name, teacher_username) VALUES (?, ?)",
            (course.course_name, course.teacher_username)
        )
        conn.commit()
        conn.close()
        return {"status": "Success", "message": f"Course '{course.course_name}' added successfully!"}
    except Exception as e:
        return {"status": "Error", "message": str(e)}


@app.get("/my-courses/{teacher_username}")
def get_my_courses(teacher_username: str):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT course_name FROM courses WHERE teacher_username = ?", (teacher_username,))
        courses = cursor.fetchall()
        conn.close()
        
        course_list = [row["course_name"] if isinstance(row, sqlite3.Row) else row[0] for row in courses]
        return {"status": "Success", "courses": course_list}
    except Exception as e:
        return {"status": "Error", "message": str(e)}


@app.get("/teacher-courses/{username}")
def get_teacher_courses(username: str):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT course_name FROM courses WHERE TRIM(teacher_username) = ?", (username.strip(),))
        courses = [row["course_name"] for row in cursor.fetchall()]
        conn.close()
        return {"status": "Success", "courses": courses}
    except Exception as e:
        return {"status": "Error", "message": str(e)}


# ==========================================
# ADMIN PANEL ENDPOINTS
# ==========================================

@app.post("/admin/add-student/")
def admin_add_student(student: AdminStudentCreate):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM students WHERE roll_number = ?", (student.roll_number,))
        existing_student = cursor.fetchone()
        
        if not existing_student:
            cursor.execute(
                "INSERT INTO students (name, roll_number, face_status) VALUES (?, ?, ?)",
                (student.name, student.roll_number, "Pending")
            )

        cursor.execute(
            "SELECT * FROM enrollments WHERE roll_number = ? AND course_name = ?",
            (student.roll_number, student.course_name)
        )
        already_enrolled = cursor.fetchone()

        if already_enrolled:
            conn.close()
            return {"status": "Error", "message": f"Student {student.name} is already enrolled in {student.course_name}!"}

        cursor.execute(
            "INSERT INTO enrollments (roll_number, course_name) VALUES (?, ?)",
            (student.roll_number, student.course_name)
        )
        conn.commit()
        conn.close()
        return {"status": "Success", "message": f"Student {student.name} enrolled in {student.course_name}!"}
        
    except Exception as e:
        return {"status": "Error", "message": str(e)}


@app.get("/pending-students/{course_name}")
def get_pending_students(course_name: str):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute('''
            SELECT s.name, s.roll_number 
            FROM students s
            JOIN enrollments e ON s.roll_number = e.roll_number
            WHERE e.course_name = ? AND s.face_status = 'Pending'
        ''', (course_name,))
        pending_students = cursor.fetchall()
        conn.close()
        
        student_list = [{"name": row["name"], "roll_number": row["roll_number"]} for row in pending_students]
        return {"status": "Success", "pending_students": student_list}
    except Exception as e:
        return {"status": "Error", "message": str(e)}


@app.post("/toggle-attendance/")
async def toggle_manual_attendance(data: dict):
    try:
        roll_number = data.get("roll_number")
        course_name = data.get("course_name").strip()
        new_status = data.get("status") 
        today_date = data.get("date", datetime.now().strftime("%Y-%m-%d"))
        time_now = datetime.now().strftime("%H:%M:%S")
        
        conn = get_db_connection()
        cursor = conn.cursor()

        cursor.execute("SELECT id FROM attendance WHERE roll_number = 'SYSTEM' AND TRIM(course_name) = ? AND date = ?", (course_name, today_date))
        if not cursor.fetchone():
            cursor.execute("INSERT INTO attendance (roll_number, course_name, date, time) VALUES (?, ?, ?, ?)", ('SYSTEM', course_name, today_date, time_now))
        
        cursor.execute("SELECT name FROM students WHERE roll_number = ?", (roll_number,))
        student = cursor.fetchone()
        student_name = student["name"] if student else "Unknown"

        if new_status == "Present":
            cursor.execute("SELECT id FROM attendance WHERE roll_number = ? AND TRIM(course_name) = ? AND date = ?", (roll_number, course_name, today_date))
            if not cursor.fetchone():
                cursor.execute("INSERT INTO attendance (roll_number, course_name, date, time) VALUES (?, ?, ?, ?)", (roll_number, course_name, today_date, time_now))
        else:
            cursor.execute("DELETE FROM attendance WHERE roll_number = ? AND TRIM(course_name) = ? AND date = ?", (roll_number, course_name, today_date))
        
        cursor.execute("INSERT INTO attendance_logs (student_name, status, course_name) VALUES (?, ?, ?)", (student_name, f"Manual {new_status} (Date: {today_date})", course_name))
        conn.commit()
        conn.close()
        return {"status": "Success", "message": f"{student_name} marked as {new_status}"}
        
    except Exception as e:
        return {"status": "Error", "message": str(e)}    


@app.get("/admin/all-students-info/")
def get_all_students_info():
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute('''
            SELECT s.name, s.roll_number, s.face_status, e.course_name, c.teacher_username
            FROM students s
            LEFT JOIN enrollments e ON s.roll_number = e.roll_number
            LEFT JOIN courses c ON TRIM(e.course_name) = TRIM(c.course_name)
            ORDER BY s.name
        ''')
        rows = cursor.fetchall()
        conn.close()

        grouped_data = {}
        for row in rows:
            roll = row["roll_number"]
            if roll not in grouped_data:
                grouped_data[roll] = {
                    "name": row["name"],
                    "roll_number": roll,
                    "face_status": row["face_status"],
                    "enrollments": []
                }
            if row["course_name"]:
                grouped_data[roll]["enrollments"].append({
                    "course_name": row["course_name"],
                    "teacher": row["teacher_username"] if row["teacher_username"] else "No Teacher Assigned"
                })
        
        return {"status": "Success", "data": list(grouped_data.values())}
    except Exception as e:
        return {"status": "Error", "message": str(e)}


@app.get("/course-sessions/{course_name}")
def get_course_sessions(course_name: str):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute('''
            SELECT DISTINCT date 
            FROM attendance 
            WHERE TRIM(course_name) = ? 
            ORDER BY date DESC
        ''', (course_name.strip(),))
        
        sessions = [row["date"] for row in cursor.fetchall()]
        conn.close()
        return {"status": "Success", "sessions": sessions}
    except Exception as e:
        return {"status": "Error", "message": str(e)}


@app.get("/attendance-by-date/{course_name}/{target_date}")
def get_attendance_by_date(course_name: str, target_date: str):
    try:
        clean_course = course_name.strip()
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute('''
            SELECT s.name, s.roll_number 
            FROM students s
            JOIN enrollments e ON s.roll_number = e.roll_number
            WHERE TRIM(e.course_name) = ? AND s.face_status = 'Registered'
        ''', (clean_course,))
        all_students = cursor.fetchall()
        cursor.execute('''
            SELECT roll_number FROM attendance 
            WHERE TRIM(course_name) = ? AND date = ?
        ''', (clean_course, target_date))
        
        present_rolls = [row["roll_number"] for row in cursor.fetchall()]
        conn.close()

        attendance_list = [
            {
                "name": student["name"],
                "roll_number": student["roll_number"],
                "status": "Present" if student["roll_number"] in present_rolls else "Absent"
            }
            for student in all_students
        ]
            
        return {
            "status": "Success", 
            "date": target_date, 
            "course_name": clean_course,
            "attendance_list": attendance_list
        }
    except Exception as e:
        return {"status": "Error", "message": str(e)}


@app.get("/admin/stats")
def get_dashboard_stats():
    try:
        today = datetime.now().strftime("%Y-%m-%d")
        conn = get_db_connection()
        cursor = conn.cursor()

        cursor.execute("SELECT COUNT(*) FROM students")
        total_students = cursor.fetchone()[0]

        cursor.execute("SELECT COUNT(DISTINCT roll_number) FROM attendance WHERE date = ? AND roll_number != 'SYSTEM'", (today,))
        present_today = cursor.fetchone()[0]

        conn.close()
        return {
            "status": "Success",
            "total_students": total_students,
            "present_today": present_today
        }
    except Exception as e:
        return {"status": "Error", "total_students": 0, "present_today": 0, "message": str(e)}

# @app.post("/admin/register-student")
# async def register_student_from_admin(
#     roll_number: str = Form(...),
#     name: str = Form(...),
#     image: UploadFile = File(...)
# ):
#     try:
#         # Absolute path configuration
#         BASE_DIR = os.path.dirname(os.path.abspath(__file__))
#         STUDENTS_DIR = os.path.join(BASE_DIR, "students_pics")
#         os.makedirs(STUDENTS_DIR, exist_ok=True)
        
#         file_path = os.path.join(STUDENTS_DIR, f"{name}_{roll_number}_front.jpg")
#         print(f"\n📍 FILE EXACT SAVE LOCATION: {file_path}\n")

#         # Save uploaded image
#         with open(file_path, "wb") as buffer:
#             shutil.copyfileobj(image.file, buffer)

#         # Clear PKL cache
#         for f in os.listdir(STUDENTS_DIR):
#             if f.endswith(".pkl"):
#                 os.remove(os.path.join(STUDENTS_DIR, f))

#         conn = get_db_connection()
#         cursor = conn.cursor()

#         cursor.execute("SELECT * FROM students WHERE roll_number = ?", (roll_number,))
#         if cursor.fetchone():
#             cursor.execute(
#                 "UPDATE students SET name = ?, face_status = 'Registered' WHERE roll_number = ?",
#                 (name, roll_number)
#             )
#         else:
#             cursor.execute(
#                 "INSERT INTO students (name, roll_number, face_status) VALUES (?, ?, 'Registered')",
#                 (name, roll_number)
#             )

#         conn.commit()
#         conn.close()

#         return {"status": "Success", "message": f"Student {name} registered successfully!"}
#     except Exception as e:
#         print(f"‼️ Admin Register Error: {e}")
#         return {"status": "Error", "message": str(e)}
@app.get("/admin/weekly-stats")
def get_weekly_stats():
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        today = datetime.now()
        start_of_week = today - timedelta(days=today.weekday())

        days_label = ["Mon", "Tue", "Wed", "Thu", "Fri"]
        weekly_data = []

        for i in range(5):
            current_day_date = (start_of_week + timedelta(days=i)).strftime("%Y-%m-%d")

            cursor.execute(
                "SELECT COUNT(DISTINCT roll_number) FROM attendance WHERE date = ? AND roll_number != 'SYSTEM'",
                (current_day_date,)
            )
            row = cursor.fetchone()
            present_count = row[0] if row else 0

            weekly_data.append({
                "day": days_label[i],
                "date": current_day_date,
                "count": present_count
            })

        conn.close()
        return {"status": "Success", "weekly_data": weekly_data}

    except Exception as e:
        return {"status": "Error", "message": str(e), "weekly_data": []}


@app.get("/admin/students")
def get_all_students():
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT id, name, roll_number, face_status FROM students ORDER BY id DESC")
        rows = cursor.fetchall()
        conn.close()
        
        students = [
            {
                "id": row[0],
                "name": row[1],
                "roll_number": row[2],
                "face_status": row[3] or "Registered"
            }
            for row in rows
        ]
        return {"status": "Success", "students": students}
    except Exception as e:
        return {"status": "Error", "message": str(e), "students": []}

