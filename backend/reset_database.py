from main import get_db_connection

print("🗑️ Initiating complete database reset...\n")

try:
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # Deleting all records from the respective tables
    cursor.execute("DELETE FROM users")
    print("✅ Cleared 'users' table (All accounts deleted).")
    
    cursor.execute("DELETE FROM courses")
    print("✅ Cleared 'courses' table.")
    
    cursor.execute("DELETE FROM attendance_logs")
    print("✅ Cleared 'attendance' table.")
    
    cursor.execute("DELETE FROM students")
    print("✅ Cleared 'students' table (All registered students removed).")

    cursor.execute("DELETE FROM enrollments")
    print("Successfully delete enrollments")
    
    # Commit the changes and close the connection
    conn.commit()
    conn.close()
    
    print("\n🎉 Database reset successful! The system is now completely empty.")
    
except Exception as e:
    print(f"\n‼️ Database Error: {e}")