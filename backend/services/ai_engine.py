# services/ai_engine.py
import os
from deepface import DeepFace
from core.config import ACTIVE_AI_MODEL, ACTIVE_DETECTOR, MATCHING_THRESHOLD

def recognize_faces(image_path: str, db_path: str = "./students_pics"):
    detected_names = set()
    
    print("\n" + "="*50)
    print(f"🔍 SCANNING WITH {ACTIVE_AI_MODEL}...")
    
    results = DeepFace.find(
        img_path=image_path,
        db_path=db_path,
        model_name=ACTIVE_AI_MODEL, 
        enforce_detection=False, 
        detector_backend=ACTIVE_DETECTOR, 
        align=True
    )

    for i, res in enumerate(results):
        if not res.empty:
            best_match_row = res.iloc[0]
            best_match_path = best_match_row['identity']
            distance = best_match_row['distance']
            
            raw_name = os.path.basename(best_match_path).split('.')[0] 
            clean_name = raw_name.split('_')[0] 

            print(f"👤 Face {i+1}: Matched with '{clean_name}' (File: {raw_name}) | Distance: {distance:.4f}")

            if distance < MATCHING_THRESHOLD: 
                detected_names.add(clean_name)
                print(f"   ✅ SUCCESS: Added {clean_name}")
            else:
                print(f"   ❌ IGNORED: Distance too high ({distance:.4f})")
        else:
            print(f"❓ Face {i+1}: No match found in database.")

    print("="*50 + "\n")
    return list(detected_names)