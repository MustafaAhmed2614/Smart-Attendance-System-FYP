from main import get_db_connection

try:
    conn = get_db_connection()
    cursor = conn.cursor()
    
    cursor.execute("DELETE FROM users")
    conn.commit()
    conn.close()
    
    print("Successfully deleted old accounts")
    print("SignUp for new acoounts")
    
except Exception as e:
    print(f"Error: {e}")