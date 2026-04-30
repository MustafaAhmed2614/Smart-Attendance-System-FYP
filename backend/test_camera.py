import cv2

# Loading OpenCV's pre-trained Face and Eye cascade models
face_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')
eye_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_eye.xml')

# Initialize the webcam feed
cap = cv2.VideoCapture(0)

print("Opening camera... (Press 'ESC' to exit)")

while cap.isOpened():
    ret, frame = cap.read()
    if not ret:
        print("Error: Failed to capture camera feed.")
        break
        
    # Convert the frame to grayscale (required for Haar Cascade processing)
    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    
    # Detect faces within the frame
    faces = face_cascade.detectMultiScale(gray, scaleFactor=1.3, minNeighbors=5)
    
    for (x, y, w, h) in faces:
        # Draw a blue bounding box around the detected face
        cv2.rectangle(frame, (x, y), (x+w, y+h), (255, 0, 0), 2)
        
        # Define the Region of Interest (ROI) to detect eyes only within the face area
        roi_gray = gray[y:y+h, x:x+w]
        roi_color = frame[y:y+h, x:x+w]
        
        # Detect eyes within the face ROI
        eyes = eye_cascade.detectMultiScale(roi_gray)
        for (ex, ey, ew, eh) in eyes:
            # Draw a green bounding box around the detected eyes
            cv2.rectangle(roi_color, (ex, ey), (ex+ew, ey+eh), (0, 255, 0), 2)

    # Display the processed frame on the screen
    cv2.imshow('FYP - Face & Eye Detection (Plan B)', frame)

    # Break the loop if the 'ESC' key is pressed
    if cv2.waitKey(1) & 0xFF == 27:
        break

# Release hardware resources and close windows
cap.release()
cv2.destroyAllWindows()