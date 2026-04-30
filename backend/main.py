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

app = FastAPI()

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