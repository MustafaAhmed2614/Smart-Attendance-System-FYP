from fastapi import FastAPI, File, UploadFile, Form
import cv2
import numpy as np
import sqlite3
import os
from deepface import DeepFace
import shutil
import uuid
import traceback # 👈 Naya tool jo chhupay hue errors pakrega

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

# Ensure folder exists
if not os.path.exists("./students_pics"):
    os.makedirs("./students_pics")

@app.get("/")
def read_root():
    return {"message": "FYP Smart Attendance API is Live!"}

# 1. REGISTER STUDENT (With X-Ray Logging)
@app.post("/register-student/")
async def register_student(name: str = Form(...), file: UploadFile = File(...)):
    try:
        print(f"\n--- 📥 NEW REGISTRATION REQUEST: {name} ---")
        
        unique_id = uuid.uuid4().hex[:5]
        file_name = f"{name}_{unique_id}.jpg"
        file_path = os.path.join("./students_pics", file_name)
        
        print(f"📸 Saving photo to: {file_path}")
        
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
            
        print("🗑️ Deleting old PKL cache so AI learns new faces...")
        for f in os.listdir("./students_pics"):
            if f.endswith(".pkl"):
                os.remove(os.path.join("./students_pics", f))
                print(f"   -> Deleted: {f}")

        print(f"✅ REGISTRATION SUCCESSFUL FOR {name}\n")
        return {"status": "Success", "message": f"Photo added for {name}!"}
    
    except Exception as e:
        print("\n‼️ ‼️ REGISTRATION ERROR ‼️ ‼️")
        traceback.print_exc() # Ye exact line number aur wajah batayega!
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

        results = DeepFace.find(
            img_path=temp_file_path,
            db_path="./students_pics",
            model_name="VGG-Face", 
            enforce_detection=False, 
            detector_backend="retinaface", 
            align=True
        )

        detected_names = set()
        
        print("\n" + "="*50)
        print("🔍 SCANNING WITH FACENET512...")
        
        for i, res in enumerate(results):
            if not res.empty:
                best_match_row = res.iloc[0]
                best_match_path = best_match_row['identity']
                distance = best_match_row['distance']
                
                # Name Extract (e.g., Mustafa_abc12 -> Mustafa)
                raw_name = os.path.basename(best_match_path).split('.')[0] 
                clean_name = raw_name.split('_')[0] 

                print(f"👤 Face {i+1}: Matched with '{clean_name}' (File: {raw_name}) | Distance: {distance:.4f}")

                if distance < 0.55: 
                    detected_names.add(clean_name)
                    print(f"   ✅ SUCCESS: Added {clean_name}")
                else:
                    print(f"   ❌ IGNORED: Distance too high ({distance:.4f})")
            else:
                print(f"❓ Face {i+1}: No match found in database.")

        print("="*50 + "\n")

        final_names = list(detected_names)

        if final_names:
            conn = sqlite3.connect('attendance.db')
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
    conn = sqlite3.connect('attendance.db')
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM attendance_logs ORDER BY timestamp DESC")
    logs = cursor.fetchall()
    conn.close()
    return {"logs": logs}