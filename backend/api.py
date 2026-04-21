from fastapi import FastAPI, File, UploadFile, Form
import cv2
import numpy as np
import sqlite3
import os
from deepface import DeepFace
import shutil
import uuid

app = FastAPI()

# --- DATABASE SETUP ---
def init_db():
    conn = sqlite3.connect('attendance.db')
    cursor = conn.cursor()
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS students (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            roll_number TEXT UNIQUE NOT NULL
        )
    ''')
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

if not os.path.exists("./students_pics"):
    os.makedirs("./students_pics")

@app.get("/")
def read_root():
    return {"message": "FYP Smart Attendance API is Live!"}

# 1. REGISTER STUDENT
@app.post("/register-student/")
async def register_student(name: str = Form(...), file: UploadFile = File(...)):
    try:
        file_path = os.path.join("./students_pics", f"{name}.jpg")
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
            
        # Clear DeepFace cache to recognize new faces
        for f in os.listdir("./students_pics"):
            if f.endswith(".pkl"):
                os.remove(os.path.join("./students_pics", f))

        return {"status": "Success", "message": f"Student {name} registered successfully!"}
    except Exception as e:
        return {"status": "Error", "message": str(e)}

# 2. DETECT ATTENDANCE (FIXED)
@app.post("/detect-attendance/")
async def detect_attendance(file: UploadFile = File(...)):
    unique_filename = f"temp_{uuid.uuid4()}.jpg"
    temp_file_path = unique_filename 
    
    try:
        # 1. Save temp file
        with open(temp_file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        # 2. DeepFace Search
        # Multiple faces ke liye ye list return karega
        results = DeepFace.find(
            img_path=temp_file_path,
            db_path="./students_pics",
            model_name="VGG-Face",
            enforce_detection=False, 
            detector_backend="opencv",
            align=False
        )

        detected_names = set() # Set use kar rahe hain taake auto-duplicate remove ho jayein
        
        # 3. Loop through each detected face
        for res in results:
            if not res.empty:
                # 0.6 Threshold (aapne jo set kiya tha, perfect hai)
                reliable_matches = res[res['distance'] < 0.6] 
                
                if not reliable_matches.empty:
                    # Sab se top wala match (lowest distance) uthayein
                    best_match = reliable_matches.iloc[0]['identity']
                    name = os.path.basename(best_match).split('.')[0]
                    detected_names.add(name) # Set mein add karein

        final_names = list(detected_names)

        # 4. Save to Database (Bulk Insertion)
        if final_names:
            conn = sqlite3.connect('attendance.db')
            cursor = conn.cursor()
            for name in final_names:
                # Check karein ke aaj ki date mein is bande ki attendance pehle toh nahi lagi?
                # (Optional: Agar aap duplicate rokhna chahte hain)
                cursor.execute("INSERT INTO attendance_logs (student_name, status) VALUES (?, ?)", (name, "Present"))
            conn.commit()
            conn.close()

        # 5. Clean up
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
        return {"status": "Error", "recognized_students": [], "message": str(e)}
# 3. VIEW LOGS
@app.get("/view-attendance/")
def view_attendance():
    conn = sqlite3.connect('attendance.db')
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM attendance_logs ORDER BY timestamp DESC")
    logs = cursor.fetchall()
    conn.close()
    return {"logs": logs}