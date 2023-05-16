// compile with
//    g++ a.cpp -o a `pkg-config --cflags --libs opencv`


#include <opencv2/core.hpp>
#include <opencv2/imgcodecs.hpp>
#include <opencv2/highgui.hpp>
#include <opencv2/imgproc.hpp>
#include <iostream>

// for string conversation
#include <sstream>
#include <iomanip>
//#include <iostream>
#include <string>
#include <cstring>
#include <algorithm>
#include <vector>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <unistd.h>


using namespace cv;

#include "visionSys0.h"
extern char* outResStr0__vision83ys48_1149;
extern NI64 outStatsCreatedNewCategory__vision83ys48_1039;
extern NI64 outStatsRecognized__vision83ys48_1040;


//typedef double NF;
//typedef void* tyObject_VisionSys0__69b9cVmnf9agBXMCdAtUelPgg;

//extern void NimMain();
//extern tyObject_VisionSys0__69b9cVmnf9agBXMCdAtUelPgg* visionSys0Create();
//extern void* visionSys0process0Cpp(void*, tyArray__IIczo5sLgwcZFxbq8BbJzA, tyArray__IIczo5sLgwcZFxbq8BbJzA);
//extern void visionSys0process0Cpp(tyObject_VisionSys0__69b9cVmnf9agBXMCdAtUelPgg*, NF*, NF*);


// helper to convert int to string with leading zeros
std::string convIntToStrLeadingZeros(int v, int width) {
    // from https://stackoverflow.com/a/225435/388614
    std::stringstream ss;
    ss << std::setw(width) << std::setfill('0') << v;
    return ss.str();
}


std::vector<std::string> split(const std::string &s, char delim) {
    // see https://stackoverflow.com/a/46931770/388614
    std::vector<std::string> result;
    std::stringstream ss(s);
    std::string item;

    while (getline (ss, item, delim)) {
        result.push_back (item);
    }

    return result;
}

void readNet(int sock, std::vector<unsigned char> &destBuffer, int len = -1) {
    const int BUFFER_SIZE = 1024*128;

    int len2=BUFFER_SIZE;
    if (len>-1) {
        len2 = std::min(BUFFER_SIZE, len);
    }
    
    char buffer[BUFFER_SIZE];
    ssize_t bytes_received = recv(sock, buffer, BUFFER_SIZE, 0);
    if (bytes_received < 0) {
        std::cerr << "Failed to receive data from server." << std::endl;
        return; // 1; // TODO< handle error >
    }

    for(int idx=0;idx<bytes_received;idx++) {
        destBuffer.push_back(buffer[idx]);
    }
}

const unsigned char MAGIC_BYTES[] = {0xAA, 0x23, 0xEF, 0xBE, 0x33};
const int MAGIC_BYTES_LENGTH = sizeof(MAGIC_BYTES) / sizeof(MAGIC_BYTES[0]);


int main(int argc, char* argv[]) {
    if (argc < 2) {
        return 1;
    }

    std::string imgSrc = std::string(argv[1]); // "net" or "disk"

    std::string SERVER_ADDRESS = "127.0.0.1";
    int SERVER_PORT = 9998; //50009;
    
    if (std::string(argv[1]) == "net") {
        // expect server adress as 2nd argument
        if (argc < 3) {
            return 1;
        }
        SERVER_ADDRESS = std::string(argv[2]);
    }


    NimMain();


    tyObject_VisionSys0__oVN47SFz1a81o5jF7529aKg* visionSys = visionSys0Create();

    int sock = -1;
    std::vector<unsigned char> buffer2;

    
    if (imgSrc == "net") {
        // connect to network
        
        const int BUFFER_SIZE = 1024*128;
        
        // Create a socket
        sock = socket(AF_INET, SOCK_STREAM, 0);
        if (sock < 0) {
            std::cerr << "Failed to create socket." << std::endl;
            return 1;
        }
        
        // Set up the server address
        struct sockaddr_in server_addr;
        server_addr.sin_family = AF_INET;
        server_addr.sin_port = htons(SERVER_PORT);
        inet_pton(AF_INET, SERVER_ADDRESS.c_str(), &server_addr.sin_addr);
        


        // Connect to the server
        if (connect(sock, (struct sockaddr*)&server_addr, sizeof(server_addr)) < 0) {
            std::cerr << "Failed to connect to server." << std::endl;
            return 1;
        }
    }


    Mat imgGrayLast;

    bool isFirstFrame = true;

    for(int currentImageNr=1; true; currentImageNr++) {
        Mat img;
        
        if (imgSrc == "disk") {
            // read image

            std::string filePath = "./genImg0/"+convIntToStrLeadingZeros(currentImageNr, 5)+".png";

            // we want to load from streetscene
            filePath = "./genImg1/"+convIntToStrLeadingZeros(currentImageNr, 5)+".jpg";

            std::string image_path = samples::findFile(filePath);
            img = imread(image_path, IMREAD_COLOR);
            if(img.empty())
            {
                std::cout << "Could not read the image: " << image_path << std::endl;
                return 1;
            }
        }
        else { // else the image src is network

            for(;;) {
                // Receive data from the server
                readNet(sock, buffer2);
                
                std::ios::fmtflags f(std::cout.flags());

                std::cout << std::hex;
                std::cout << (int)buffer2[0] << std::endl;
                std::cout << (int)buffer2[1] << std::endl;
                std::cout << (int)buffer2[2] << std::endl;
                std::cout << (int)buffer2[3] << std::endl;
                std::cout << (int)buffer2[4] << std::endl;

                std::cout.flags(f);

                std::cout << "buffer2 len=" << buffer2.size() << std::endl;

                // Search for the magic byte pattern
                unsigned char *magic_byte_ptr;
                magic_byte_ptr = std::search(&buffer2[0], &buffer2[0] + buffer2.size(), MAGIC_BYTES, MAGIC_BYTES + MAGIC_BYTES_LENGTH);
                if (magic_byte_ptr == &buffer2[0] + buffer2.size()) { // wasn't found?
                    //std::cerr << "Magic byte pattern not found." << std::endl;
                    //return 1;
                }
                else {
                    // remove all until end of magic pattern
                    int z = magic_byte_ptr - &buffer2[0];
                    z += MAGIC_BYTES_LENGTH;

                    for(int z0=0;z0<z;z0++) {
                        buffer2.erase(buffer2.begin());
                    }

                    break;
                }
            }
        
            // Read the length of the payload
            //uint32_t payload_length;
            //if (magic_byte_ptr + 4 > &buffer2[0] + buffer2.size()) {
            //    std::cerr << "Insufficient data to read payload length." << std::endl;
            //    return 1;
            //}
            //std::memcpy(&payload_length, magic_byte_ptr + MAGIC_BYTES_LENGTH, sizeof(payload_length));
            //payload_length = ntohl(payload_length);
            
            uint32_t payload_length;
            if (buffer2.size()<4) {
                std::cerr << "Insufficient data to read payload length." << std::endl;
                return 1;
            }
            std::memcpy(&payload_length, &buffer2[0], sizeof(payload_length));
            payload_length = ntohl(payload_length);
            

            std::cout << "payload length="<<payload_length<< std::endl;

            for(int idx=0;idx<4;idx++) {
                buffer2.erase(buffer2.begin());
            }

            // Read the payload
            //if (magic_byte_ptr + MAGIC_BYTES_LENGTH + sizeof(payload_length) + payload_length > &buffer2[0] + bytes_received) {

            int remLength = payload_length;

            std::vector<unsigned char> payload2;
            
            while(remLength>0) {
                if(buffer2.size()==0) { // buffer underrun?
                    // refill from network
                    readNet(sock, buffer2, remLength);

                    continue;
                }

                unsigned char v = buffer2[0];
                buffer2.erase(buffer2.begin());
                payload2.push_back(v);

                remLength--;
            }
            //unsigned char* payload_ptr = magic_byte_ptr + MAGIC_BYTES_LENGTH + sizeof(payload_length);
            //std::string payload(payload_ptr, payload_ptr + payload_length);
            
            // Print the payload
            //std::cout << "Received payload: " << payload << std::endl;

            std::cout << "try to decode received jpeg image..." << std::endl;

            // see https://stackoverflow.com/questions/14727267/opencv-read-jpeg-image-from-buffer

            // Create a Size(1, nSize) Mat object of 8-bit, single-byte elements
            Mat rawData(1, payload2.size(), CV_8UC1, (void*)&payload2[0]);

            img = cv::imdecode(rawData, 0);
            if (img.data == NULL) {
                // Error reading raw image data
                std::cout << "...error" << std::endl;
            }
            else {
                std::cout << "...success" << std::endl;
            }

        }
        
        // convert to grayscale
        Mat imgGray2;
        switch (img.type()) {
            case CV_8UC1:
                imgGray2 = img;

                std::cout << "The image is grayscale." << std::endl;
                break;
            case CV_8UC3:
                cv::cvtColor(img, imgGray2, cv::COLOR_BGR2GRAY);
                
                std::cout << "The image is RGB." << std::endl;
                break;
            case CV_8UC4:
                std::cout << "The image is RGBA." << std::endl;
                break;
            default:
                std::cout << "The image has an unknown color type." << std::endl;
                break;
        }
        
        Mat imgGray;
        cv::resize(imgGray2, imgGray, cv::Size(128, 80), cv::INTER_LINEAR); // size is (width, height)
  
        
        if (isFirstFrame) {
            imgGrayLast = imgGray;
        }
        isFirstFrame = false;

        // read pixels
        // i is by column
        // j is by row
        std::vector<double> arrCurrent;
        for(int j=0;j<imgGray.rows;j++) {
            for (int i=0;i<imgGray.cols;i++) {
                uchar val0 = imgGray.at<uchar>(j,i);
                arrCurrent.push_back(val0/255.0);
            }
        }

        std::vector<double> arrLast;
        for(int j=0;j<imgGrayLast.rows;j++) {
            for (int i=0;i<imgGrayLast.cols;i++) {
                uchar val0 = imgGrayLast.at<uchar>(j,i);
                arrLast.push_back(val0/255.0);
            }
        }


        {
            visionSys0process0Cpp(visionSys, &arrCurrent[0], &arrLast[0]);

            std::cout << "" << std::endl;
            std::cout << "DBG: stats: createdNewCategory="<<outStatsCreatedNewCategory__vision83ys48_1039 << std::endl;
            std::cout << "DBG: stats: recognized        ="<<outStatsRecognized__vision83ys48_1040 << std::endl;
        
            convClassnWithRectsToStrCpp(visionSys); // convert classes to string
        }

        Mat dbgCanvas; // canvas for debugging
        cv::cvtColor(imgGray, dbgCanvas, cv::COLOR_GRAY2BGR);

        { // take string containing the result from the vision system apart
            char* outResStr0 = outResStr0__vision83ys48_1149;

            std::string outResStr1 = std::string(outResStr0);
            std::vector<std::string> v0 = split(outResStr1, '\n');

            // iterate to parse
            for (std::string iLine : v0) {
                std::cout << "C++ " << iLine << std::endl;

                std::vector<std::string> v1 = split(iLine, ',');

                std::string minxStr = v1[0];
                std::string minyStr = v1[1];
                std::string maxxStr = v1[2];
                std::string maxyStr = v1[3];
                std::string classStr = v1[4];

                int minx = stoi(minxStr);
                int miny = stoi(minyStr);
                int maxx = stoi(maxxStr);
                int maxy = stoi(maxyStr);
                int class_ = stoi(classStr);

                // draw to debug canvas
                cv::Rect rect(minx, miny, maxx-minx, maxy-miny);
                cv::rectangle(dbgCanvas, rect, cv::Scalar(255, 0, 0));
            }
        }





        //imshow("Display window", img);
        imshow("Display window", dbgCanvas);
        int k = waitKey(0); // Wait for a keystroke in the window

        imgGrayLast = imgGray;
    }

    return 0;
}
