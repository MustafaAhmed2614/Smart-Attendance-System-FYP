import cv2

# OpenCV ke pre-trained Face aur Eye models load kar rahe hain
face_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')
eye_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_eye.xml')

# Camera open karein
cap = cv2.VideoCapture(0)

print("Camera open ho raha hai... (Band karne ke liye 'ESC' dabayen)")

while cap.isOpened():
    ret, frame = cap.read()
    if not ret:
        print("Camera feed nahi mil rahi.")
        break
        
    # AI processing ke liye frame ko black & white (grayscale) karna parta hai
    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    
    # Chehre dhoondna
    faces = face_cascade.detectMultiScale(gray, scaleFactor=1.3, minNeighbors=5)
    
    for (x, y, w, h) in faces:
        # Chehre par neela (Blue) box banayen
        cv2.rectangle(frame, (x, y), (x+w, y+h), (255, 0, 0), 2)
        
        # Ab sirf us chehre ke andar ankhein dhoondein (poori screen par nahi)
        roi_gray = gray[y:y+h, x:x+w]
        roi_color = frame[y:y+h, x:x+w]
        
        eyes = eye_cascade.detectMultiScale(roi_gray)
        for (ex, ey, ew, eh) in eyes:
            # Ankhon par hara (Green) box banayen
            cv2.rectangle(roi_color, (ex, ey), (ex+ew, ey+eh), (0, 255, 0), 2)

    # Screen par display karein
    cv2.imshow('FYP - Face & Eye Detection (Plan B)', frame)

    # ESC button dabane se band hoga
    if cv2.waitKey(1) & 0xFF == 27:
        break

# Safai (Cleanup)
cap.release()
cv2.destroyAllWindows()