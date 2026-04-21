from fastapi import FastAPI, File, UploadFile, Form
import cv2
import numpy as np
import sqlite3
import os
from deepface import DeepFace
import shutil

app = FastAPI()

# --- DATABASE SETUP ---
def init_db():
    conn = sqlite3.connect('attendance.db')
    cursor = conn.cursor()
    # Students Table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS students (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            roll_number TEXT UNIQUE NOT NULL
        )
    ''')
    # Attendance Logs Table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS attendance_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            student_name TEXT,
            status TEXT,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    conn.commit()
    conn.close()

init_db()

# Create directory for student photos if it doesn't exist
if not os.path.exists("./students_pics"):
    os.makedirs("./students_pics")

# --- ROUTES ---

@app.get("/")
def read_root():
    return {"message": "FYP Smart Attendance API is Live!"}

# 1. NEW: STUDENT REGISTRATION ROUTE
@app.post("/register-student/")
async def register_student(name: str = Form(...), file: UploadFile = File(...)):
    try:
        # File name student ke naam par rakhenge
        # Extension fix kar dete hain .jpg taake database clean rahe
        file_path = os.path.join("./students_pics", f"{name}.jpg")
        
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
            
        # DeepFace ki .pkl file delete karna zaroori hai taake wo naya chehra scan kare
        for f in os.listdir("./students_pics"):
            if f.endswith(".pkl"):
                os.remove(os.path.join("./students_pics", f))

        return {"status": "Success", "message": f"Student {name} registered successfully!"}
    except Exception as e:
        return {"status": "Error", "message": str(e)}

# 2. UPDATED: ATTENDANCE DETECTION ROUTE
@app.post("/detect-attendance/")
async def detect_and_mark(file: UploadFile = File(...)):
    temp_path = f"temp_{file.filename}"
    with open(temp_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    try:
        # DeepFace Recognition
        results = DeepFace.find(img_path=temp_path, 
                                db_path="./students_pics", 
                                enforce_detection=False,
                                model_name="VGG-Face", 
                                distance_metric="cosine")
        
        print("DeepFace RAW Result:", results)

        recognized_students = []
        
        if len(results) > 0 and not results[0].empty:
            for index, row in results[0].iterrows():
                full_path = row['identity']
                # Har qism ke extension (.jpeg, .png) ko handle karne ke liye:
                filename_with_ext = os.path.basename(full_path)
                s_name = os.path.splitext(filename_with_ext)[0]
                
                if s_name not in recognized_students:
                    recognized_students.append(s_name)
                    
                    # Database Entry
                    conn = sqlite3.connect('attendance.db')
                    cursor = conn.cursor()
                    cursor.execute("INSERT INTO attendance_logs (student_name, status) VALUES (?, ?)", (s_name, "Present"))
                    conn.commit()
                    conn.close()

        # Cleanup
        if os.path.exists(temp_path):
            os.remove(temp_path)

        return {
            "status": "Success",
            "recognized_students": recognized_students,
            "message": f"Attendance marked for: {', '.join(recognized_students)}" if recognized_students else "No student recognized"
        }

    except Exception as e:
        if os.path.exists(temp_path): os.remove(temp_path)
        print(f"Error occurred: {e}")
        return {"status": "Error", "message": str(e)}

# 3. BONUS: VIEW ATTENDANCE LOGS
@app.get("/view-attendance/")
def view_attendance():
    conn = sqlite3.connect('attendance.db')
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM attendance_logs ORDER BY timestamp DESC")
    logs = cursor.fetchall()
    conn.close()
    return {"logs": logs}