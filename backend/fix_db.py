from main import get_db_connection

try:
    conn = get_db_connection()
    cursor = conn.cursor()
    # Yeh line purane table mein ek naya column add kar degi
    cursor.execute("ALTER TABLE attendance ADD COLUMN course_name TEXT DEFAULT 'Unknown'")
    conn.commit()
    conn.close()
    print("✅ Database updated: 'course_name' column successfully added to attendance table!")
except Exception as e:
    print(f"Error: {e}")