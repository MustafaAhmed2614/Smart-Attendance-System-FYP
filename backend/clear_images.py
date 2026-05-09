import os
import shutil

print("🗑️ Initiating cleanup of old image directories...\n")

# Directories where student and attendance images are stored
folders_to_clear = [
    "./students_pics", 
    "./attendance_photos", 
    "./save_pictures"
]

for folder in folders_to_clear:
    if os.path.exists(folder):
        # Remove the entire directory tree (including all files inside)
        shutil.rmtree(folder) 
        # Recreate the empty directory to prevent FileNotFoundError during runtime
        os.makedirs(folder)   
        print(f"✅ Successfully cleared directory: {folder}")
    else:
        print(f"⚠️ Directory not found (already clean): {folder}")

# Crucial step: Delete the AI model's cache file to prevent stale face data
if os.path.exists("representations_arcface.pkl"):
    os.remove("representations_arcface.pkl")
    print("✅ Successfully deleted AI model cache (.pkl file).")

print("\n🎉 Cleanup complete! All previous images and cached data have been successfully removed.")