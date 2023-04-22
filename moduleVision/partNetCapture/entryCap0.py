import time
import cv2

import socket
import numpy as np

connectToSrv = True # connect to server?

# Define the server address and port
SERVER_ADDRESS = 'localhost'
SERVER_PORT = 50008

sock = None

if connectToSrv:
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.connect((SERVER_ADDRESS, SERVER_PORT))


cap = cv2.VideoCapture(0) # video capture source camera (Here webcam of laptop) 

while(True):
    print('it')
    ret,frame = cap.read() # return a single frame in variable `frame`

    h, w = frame.shape[:2]
    frame1 = cv2.resize(frame, (int(h/4), int(w/4)))

    # see https://stackoverflow.com/questions/40768621/python-opencv-jpeg-compression-in-memory
    encode_param = [int(cv2.IMWRITE_JPEG_QUALITY), 80]
    result, encimg = cv2.imencode('.jpg', frame1, encode_param)

    print(type(encimg), len(encimg))

    len0 = len(encimg)
    lenArr0 = (len0 >>  0) % 256
    lenArr1 = (len0 >>  8) % 256
    lenArr2 = (len0 >> 16) % 256
    lenArr3 = (len0 >> 24) % 256
    

    # Create a NumPy array to send
    arr0 = np.array([0xAA, 0x23, 0xEF, 0xBE, 0x33], dtype=np.uint8)
    arr1 = np.array([lenArr3, lenArr2, lenArr1, lenArr0], dtype=np.uint8)
    arr2 = np.append(arr0, arr1)
    arr3 = np.append(arr2, encimg)

    print(len(arr3))
    
    # send the byte array to the server
    byteArray = arr3.tobytes()
    if sock is not None:
        sock.sendall(byteArray)



    #cv2.imshow('img1',frame) #display the captured image
    #if cv2.waitKey(1) & 0xFF == ord('y'): #save on pressing 'y' 
    #    #cv2.imwrite('images/c1.png',frame)
    #    cv2.destroyAllWindows()
    #    break


    time.sleep(0.3) # 3fps max is enough

cap.release()

# Close the socket
if sock is not None:
    sock.close()

