import os
from PIL import Image

def optimize_all_existing_images():
    STUDENTS_DIR = "students_pics"
    
    if not os.path.exists(STUDENTS_DIR):
        print("Folder mojood nahi hai!")
        return

    print("Purani images ko optimize karna shuru kar rahe hain...")
    
    count = 0
    for filename in os.listdir(STUDENTS_DIR):
        # Sirf image files par kaam karein
        if filename.lower().endswith(('.png', '.jpg', '.jpeg')):
            file_path = os.path.join(STUDENTS_DIR, filename)
            try:
                # Image open karein, resize karein aur quality optimize karke overwrite kar dein
                img = Image.open(file_path)
                img = img.resize((300, 300), Image.Resampling.LANCZOS)
                img.save(file_path, optimize=True, quality=85)
                count += 1
                print(f"Optimized: {filename}")
            except Exception as e:
                print(f"Error in {filename}: {e}")
                
    print(f"Mukammal ho gaya! Total {count} images ko resize aur optimize kar diya gaya hai.")

# Agar is file ko direct run karna ho:
if __name__ == "__main__":
    optimize_all_existing_images()