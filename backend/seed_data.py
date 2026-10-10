from datetime import datetime, timedelta
import sqlite3
import random

def seed_weekly_attendance():
    # Database file connection
    conn = sqlite3.connect('attendance.db') 
    cursor = conn.cursor()

    today = datetime.now()
    start_of_week = today - timedelta(days=today.weekday()) # Monday

    # Sample roll numbers and course
    sample_students = ["2021-CS-01", "2021-CS-02", "2021-CS-03", "2021-CS-04", "2021-CS-05"]
    course_name = "Computer Science"

    for i in range(5):
        date_str = (start_of_week + timedelta(days=i)).strftime("%Y-%m-%d")
        
        # Har din 2 se 5 random students ki entry
        daily_present = random.sample(sample_students, k=random.randint(2, 5))
        
        for roll in daily_present:
            cursor.execute("""
                INSERT INTO attendance (roll_number, date, time, course_name) 
                VALUES (?, ?, '09:00:00', ?)
            """, (roll, date_str, course_name))

    conn.commit()
    conn.close()
    print("Success: Is week ka test attendance data insert ho gaya hai!")

if __name__ == "__main__":
    seed_weekly_attendance()