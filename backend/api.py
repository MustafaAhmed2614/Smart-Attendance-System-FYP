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
            
        # Clear DeepFace cache
        for f in os.listdir("./students_pics"):
            if f.endswith(".pkl"):
                os.remove(os.path.join("./students_pics", f))

        return {"status": "Success", "message": f"Student {name} registered successfully!"}
    except Exception as e:
        return {"status": "Error", "message": str(e)}

# 2. DETECT ATTENDANCE
@app.post("/detect-attendance/")
async def detect_attendance(file: UploadFile = File(...)):
    unique_filename = f"temp_{uuid.uuid4()}.jpg"
    temp_file_path = unique_filename 
    
    try:
        # Save temp file
        with open(temp_file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        # DeepFace Search with RetinaFace (More Accurate for Group Photos)
        results = DeepFace.find(
            img_path=temp_file_path,
            db_path="./students_pics",
            model_name="VGG-Face",
            enforce_detection=False, 
            detector_backend="retinaface", # 👈 High accuracy detector
            align=True
        )

        detected_names = set()
        
        print("\n" + "="*50)
        print("🔍 SCANNING GROUP PHOTO FOR FACES...")
        
        # results list of dataframes hoti hai (one for each detected face)
        for i, res in enumerate(results):
            if not res.empty:
                # Top match details
                best_match_row = res.iloc[0]
                best_match_path = best_match_row['identity']
                distance = best_match_row['distance']
                name = os.path.basename(best_match_path).split('.')[0]

                # Debug print to terminal
                print(f"👤 Face {i+1}: Matched with '{name}' | Distance: {distance:.4f}")

                # 0.48 Threshold (Strict for filtering out background noise)
                if distance < 0.48:
                    detected_names.add(name)
                    print(f"   ✅ SUCCESS: Added {name}")
                else:
                    print(f"   ❌ IGNORED: Distance too high ({distance:.2f})")
            else:
                print(f"❓ Face {i+1}: No match found in database.")

        print("="*50 + "\n")

        final_names = list(detected_names)

        # Save to Database
        if final_names:
            conn = sqlite3.connect('attendance.db')
            cursor = conn.cursor()
            for name in final_names:
                cursor.execute("INSERT INTO attendance_logs (student_name, status) VALUES (?, ?)", (name, "Present"))
            conn.commit()
            conn.close()

        # Clean up temp file
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
    conn = sqlite3.connect('attendance.db')
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM attendance_logs ORDER BY timestamp DESC")
    logs = cursor.fetchall()
    conn.close()
    return {"logs": logs}