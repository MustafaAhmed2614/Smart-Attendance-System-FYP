# main.py
from fastapi import FastAPI, File, UploadFile, Form
import os
import shutil
import uuid
import traceback 
from fastapi import Response
import csv                   
import io      
import cv2        # <--- Yeh import top par hona chahiye
import base64     # <--- Yeh import top par hona chahiye
import numpy as np
from datetime import datetime              
# Clean Architecture imports
from db.database import init_db, get_db_connection
from services.ai_engine import recognize_faces
from pydantic import BaseModel
import sqlite3
from passlib.context import CryptContext
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



# Bcrypt ka setup
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# 1. Naya password hash karne ka function (Signup ke liye)
def get_password_hash(password):
    return pwd_context.hash(password)

# 2. Password check karne ka function (Login ke liye)
def verify_password(plain_password, hashed_password):
    return pwd_context.verify(plain_password, hashed_password)
@app.get("/")
def read_root():
    return {"message": "FYP Smart Attendance API is Live! (Clean Architecture)"}

# 1. REGISTER STUDENT (Hybrid Flow Updated)
import os # Upar top par check kar lena ke yeh import hai ya nahi

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
        
        # 🚀 YEH LINE MISSING THI: Yeh line khud check karegi aur folder bana degi!
        os.makedirs("./students_pics", exist_ok=True)
        
        # 1. Tasweerein Save Karna
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
            
        # 2. Purane AI models (PKL) delete karna taake naye faces add ho sakein
        print("🗑️ Deleting old PKL cache so AI learns new faces...")
        for f in os.listdir("./students_pics"):
            if f.endswith(".pkl"):
                os.remove(os.path.join("./students_pics", f))
                
        # 3. Database mein status 'Pending' se 'Registered' karna
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
# 2. DETECT ATTENDANCE

ATTENDANCE_IMG_DIR = "attendance_photos"
os.makedirs(ATTENDANCE_IMG_DIR, exist_ok=True)

@app.post("/detect-attendance/")
async def detect_attendance(
    file: UploadFile = File(...), 
    course_name: str = Form(...) # Removed default "AI" to ensure it uses the exact flutter value
):
    # 🚀 FIX 1: Remove extra spaces from course name
    clean_course_name = course_name.strip()
    
    current_time = datetime.now()
    timestamp = current_time.strftime("%Y-%m-%d_%H-%M-%S")
    today_date = current_time.strftime("%Y-%m-%d")
    time_now = current_time.strftime("%H:%M:%S")
    
    # Naya File Path
    filename = f"{clean_course_name}_{timestamp}.jpg"
    file_path = os.path.join(ATTENDANCE_IMG_DIR, filename) 
    
    try:
        # Save image permanently
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        # AI Engine logic returns list of names (e.g., ["Mustafa", "Ali"])
        final_names = recognize_faces(file_path)

        img_base64 = None 

        if final_names:
            conn = get_db_connection()
            cursor = conn.cursor()
            
            # List to store only those names who are actually in the class
            valid_students_marked = []
            
            for name in final_names:
                # 🚀 SMART FIX: SQL JOIN lagaya hai! 
                # Check karo ke bacha mojood hai AND is course mein enrolled hai
                cursor.execute('''
                    SELECT s.roll_number 
                    FROM students s
                    JOIN enrollments e ON s.roll_number = e.roll_number
                    WHERE s.name = ? AND TRIM(e.course_name) = ?
                ''', (name, clean_course_name))
                
                student_row = cursor.fetchone()
                
                if student_row:
                    roll_no = student_row["roll_number"]
                    valid_students_marked.append(name) # Valid student mil gaya
                    
                    # Duplicate check
                    cursor.execute('''
                        SELECT id FROM attendance 
                        WHERE roll_number = ? AND TRIM(course_name) = ? AND date = ?
                    ''', (roll_no, clean_course_name, today_date))
                    
                    exists = cursor.fetchone()
                    
                    if not exists:
                        # Mark in Daily Attendance
                        cursor.execute(
                            "INSERT INTO attendance (roll_number, course_name, date, time) VALUES (?, ?, ?, ?)", 
                            (roll_no, clean_course_name, today_date, time_now)
                        )
                        # Save in Logs
                        cursor.execute(
                            "INSERT INTO attendance_logs (student_name, status, course_name) VALUES (?, ?, ?)", 
                            (name, "Present", clean_course_name)
                        )
                        print(f"✅ Marked {name} ({roll_no}) in {clean_course_name}")
                else:
                    # 🚀 Agar bacha kisi aur course ka hai, toh ignore kar do
                    print(f"⚠️ Ignored '{name}': Recognized by AI but NOT enrolled in {clean_course_name}")

            conn.commit()
            conn.close()

            # --- Image processing (Drawing names) ---
            image = cv2.imread(file_path)
            y_position = 30
            
            # 🚀 FIX 1: Tasweer par sirf unke naam likho jo waqai is course mein hain
            for name in valid_students_marked:
                cv2.putText(image, f"Identified: {name}", (20, y_position), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 255, 0), 2)
                y_position += 30 
                
            _, buffer = cv2.imencode('.jpg', image)
            img_base64 = base64.b64encode(buffer).decode('utf-8')

        # 🚀 FIX 2: Flutter App ko sirf 'valid_students_marked' ki list bhejo
        # Agar final_names empty hai (kuch detect nahi hua), toh empty list bhejo
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
    # 3. VIEW LOGS
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
        # Python level extra space removal
        clean_course = course_name.strip()
        print(f"\n📊 Fetching attendance list for: '{clean_course}'")
        
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Aaj ki date
        today = datetime.now().strftime("%Y-%m-%d")
        
        # 1. Fetch enrolled students (using TRIM to ignore database spaces)
        cursor.execute('''
            SELECT s.name, s.roll_number 
            FROM students s
            JOIN enrollments e ON s.roll_number = e.roll_number
            WHERE TRIM(e.course_name) = ? AND s.face_status = 'Registered'
        ''', (clean_course,))
        all_students = cursor.fetchall()
        
        # 2. Fetch the roll numbers of students who are marked present today
        cursor.execute('''
            SELECT roll_number FROM attendance 
            WHERE TRIM(course_name) = ? AND date = ?
        ''', (clean_course, today))
        
        present_rolls = [row["roll_number"] for row in cursor.fetchall()]
        print(f"✅ Found Present Roll Numbers Today: {present_rolls}")
        
        conn.close()
        
        # 3. Create a combined list with Present/Absent status
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
        print(f"‼️ Error fetching daily attendance: {e}")
        return {"status": "Error", "message": str(e)}
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
async def signup(user: dict): # (Aapne pydantic model use kiya ho toh woh lagayen)
    username = user.get("username")
    raw_password = user.get("password")
    role = user.get("role")
    
    # 🚀 Yahan hum plain password ko hash mein convert kar rahe hain
    hashed_password = get_password_hash(raw_password)
    
    # Ab is hashed_password ko database mein INSERT karein (plain ko nahi!)
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            "INSERT INTO users (username, password, role) VALUES (?, ?, ?)",
            (username, hashed_password, role) # Yahan hashed bhej rahe hain
        )
        conn.commit()
        return {"status": "Success", "message": "Account created securely!"}
    except Exception as e:
        return {"status": "Error", "message": "Username already exists!"}
    finally:
        conn.close()
# 7. LOGIN API (Account Check karne ke liye)
@app.post("/login/")
async def login(user: dict):
    username = user.get("username")
    raw_password = user.get("password")
    role = user.get("role")
    
    conn = get_db_connection()
    cursor = conn.cursor()
    # Pura user data mangwayen
    cursor.execute("SELECT password, role FROM users WHERE username = ?", (username,))
    db_user = cursor.fetchone()
    conn.close()

    # Agar user nahi mila
    if not db_user:
        return {"status": "Error", "message": "User not found!"}

    db_hashed_password = db_user["password"]
    db_role = db_user["role"]

    # 🚀 Yahan checking ho rahi hai! (True ya False aayega)
    is_password_correct = verify_password(raw_password, db_hashed_password)

    if not is_password_correct:
        return {"status": "Error", "message": "Incorrect password!"}
        
    if role != db_role:
        return {"status": "Error", "message": "Incorrect role selected!"}

    return {"status": "Success", "message": "Login successful!"}
# 8. STUDENT ATTENDANCE API (Sirf apni attendance dekhne ke liye)
# 8. STUDENT ATTENDANCE API (Updated for Debugging)
@app.get("/my-attendance/{roll_number}")
def get_my_attendance(roll_number: str):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # 1. Student ka naam nikalna
        cursor.execute("SELECT name FROM students WHERE roll_number = ?", (roll_number,))
        student = cursor.fetchone()
        
        if not student:
            conn.close()
            return {"status": "Error", "message": "Student not found!"}
            
        student_name = student[0]

        # 🚀 FIX 1: Sirf wo courses nikalen jin mein yeh roll_number officially enrolled hai
        cursor.execute('''
            SELECT TRIM(course_name) 
            FROM enrollments 
            WHERE roll_number = ?
        ''', (roll_number,))
        enrolled_courses = [row[0] for row in cursor.fetchall()]

        # Agar bacha kisi bhi course mein enrolled nahi hai, toh empty list bhej dein
        if not enrolled_courses:
            conn.close()
            return {
                "status": "Success", 
                "student_name": student_name,
                "attendance_data": []
            }

        # 🚀 FIX 2: EXACT name match karein (=) aur sirf IN enrolled_courses ka data laayein
        # Dynamic query string taake multi-course filter ho sakay
        placeholders = ','.join(['?'] * len(enrolled_courses))
        query = f'''
            SELECT status, timestamp, course_name 
            FROM attendance_logs 
            WHERE student_name = ? AND TRIM(course_name) IN ({placeholders}) 
            ORDER BY timestamp DESC
        '''
        
        # Query run karne ke liye parameters (Name + Saare enrolled courses ki list)
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
            
            # Grouping logic
            if course_name not in grouped_data:
                grouped_data[course_name] = {}
                
            if date_only not in grouped_data[course_name]:
                grouped_data[course_name][date_only] = {
                    "status": status,
                    "date": timestamp_str
                }
                
        final_output = []
        for course, dates in grouped_data.items():
            final_output.append({
                "course_name": course,
                "records": list(dates.values())
            })

        return {
            "status": "Success", 
            "student_name": student_name,
            "attendance_data": final_output
        }
        
    except Exception as e:
        print(f"‼️ API ERROR: {str(e)}")
        return {"status": "Error", "message": str(e)}
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
        
        # Step 1: Check if the student already exists in the main students table
        cursor.execute("SELECT * FROM students WHERE roll_number = ?", (student.roll_number,))
        existing_student = cursor.fetchone()
        
        if not existing_student:
            # Student is new, add them to the 'students' table
            cursor.execute(
                "INSERT INTO students (name, roll_number, face_status) VALUES (?, ?, ?)",
                (student.name, student.roll_number, "Pending")
            )
            print(f"New student {student.name} registered in the system.")
        else:
            print(f"Student {student.name} already exists. Proceeding to course enrollment.")

        # Step 2: Check if the student is already enrolled in this specific course
        cursor.execute(
            "SELECT * FROM enrollments WHERE roll_number = ? AND course_name = ?",
            (student.roll_number, student.course_name)
        )
        already_enrolled = cursor.fetchone()

        if already_enrolled:
            conn.close()
            return {
                "status": "Error", 
                "message": f"Student {student.name} is already enrolled in {student.course_name}!"
            }

        # Step 3: Enroll the student in the target course
        cursor.execute(
            "INSERT INTO enrollments (roll_number, course_name) VALUES (?, ?)",
            (student.roll_number, student.course_name)
        )
        
        conn.commit()
        conn.close()
        
        return {
            "status": "Success", 
            "message": f"Student {student.name} successfully enrolled in {student.course_name}!"
        }
        
    except Exception as e:
        print(f"API ERROR in admin_add_student: {str(e)}")
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
    

@app.post("/toggle-attendance/")
async def toggle_manual_attendance(data: dict):
    try:
        roll_number = data.get("roll_number")
        course_name = data.get("course_name").strip()
        new_status = data.get("status") 
        
        # 🚀 MAIN FIX: Ab hum 'date' frontend se mangwayenge. Agar nahi aayegi toh aaj ki date use hogi.
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
        print(f"‼️ Error toggling manual attendance: {e}")
        return {"status": "Error", "message": str(e)}    
@app.get("/teacher-courses/{username}")
def get_teacher_courses(username: str):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # 🚀 TRIM use karein taake extra spaces filter mein masla na karein
        cursor.execute("SELECT course_name FROM courses WHERE TRIM(teacher_username) = ?", (username.strip(),))
        courses = [row["course_name"] for row in cursor.fetchall()]
        
        conn.close()
        return {"status": "Success", "courses": courses}
    except Exception as e:
        return {"status": "Error", "message": str(e)}
    
@app.get("/admin/all-students-info/")
def get_all_students_info():
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # Fetch all students, their enrolled courses, and the respective teachers
        # using LEFT JOIN so even students without courses show up
        cursor.execute('''
            SELECT s.name, s.roll_number, s.face_status, e.course_name, c.teacher_username
            FROM students s
            LEFT JOIN enrollments e ON s.roll_number = e.roll_number
            LEFT JOIN courses c ON TRIM(e.course_name) = TRIM(c.course_name)
            ORDER BY s.name
        ''')
        
        rows = cursor.fetchall()
        conn.close()

        # Group the fetched data by student roll number
        grouped_data = {}
        for row in rows:
            roll = row["roll_number"]
            
            # Initialize student record if not already in dictionary
            if roll not in grouped_data:
                grouped_data[roll] = {
                    "name": row["name"],
                    "roll_number": roll,
                    "face_status": row["face_status"],
                    "enrollments": []
                }
            
            # Add course and teacher details if the student is enrolled in a course
            if row["course_name"]:
                grouped_data[roll]["enrollments"].append({
                    "course_name": row["course_name"],
                    "teacher": row["teacher_username"] if row["teacher_username"] else "No Teacher Assigned"
                })
        
        # Convert dictionary to a list format for Flutter
        students_list = list(grouped_data.values())
        print(f"Successfully fetched {len(students_list)} students for admin view.")

        return {"status": "Success", "data": students_list}
        
    except Exception as e:
        print(f"API ERROR in get_all_students_info: {str(e)}")
        return {"status": "Error", "message": str(e)}
    
# ==========================================
# 🕒 TEACHER HISTORY APIs (Date & Time Filter)
# ==========================================

# 1. API: Kisi specific course ki saari Dates/Sessions mangwane ke liye
@app.get("/course-sessions/{course_name}")
def get_course_sessions(course_name: str):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # DISTINCT use kiya hai taake ek date list mein bar bar repeat na ho
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
        print(f"‼️ API ERROR in get_course_sessions: {str(e)}")
        return {"status": "Error", "message": str(e)}

# 2. API: Kisi bhi purani Date (Session) ki Attendance Details dekhne ke liye
@app.get("/attendance-by-date/{course_name}/{target_date}")
def get_attendance_by_date(course_name: str, target_date: str):
    try:
        clean_course = course_name.strip()
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Step A: Us course ke saare registered bachon ki list nikalein
        cursor.execute('''
            SELECT s.name, s.roll_number 
            FROM students s
            JOIN enrollments e ON s.roll_number = e.roll_number
            WHERE TRIM(e.course_name) = ? AND s.face_status = 'Registered'
        ''', (clean_course,))
        all_students = cursor.fetchall()
        
        # Step B: Us specific date par jo bachay present thay, unke roll numbers nikalein
        cursor.execute('''
            SELECT roll_number FROM attendance 
            WHERE TRIM(course_name) = ? AND date = ?
        ''', (clean_course, target_date))
        
        present_rolls = [row["roll_number"] for row in cursor.fetchall()]
        conn.close()
        
        # Step C: Match karke ek complete Final List tayar karein
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
            "date": target_date, 
            "course_name": clean_course,
            "attendance_list": attendance_list
        }
        
    except Exception as e:
        print(f"‼️ API ERROR in get_attendance_by_date: {str(e)}")
        return {"status": "Error", "message": str(e)}