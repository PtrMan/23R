// compile with
//    g++ a.cpp -o a `pkg-config --cflags --libs opencv`

// for string conversation
#include <sstream>
#include <iomanip>

#include <opencv2/core.hpp>
#include <opencv2/imgcodecs.hpp>
#include <opencv2/highgui.hpp>
#include <opencv2/imgproc.hpp>
#include <iostream>
using namespace cv;

#include "visionSys0.h"

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


int main()
{
    NimMain();


    tyObject_VisionSys0__69b9cVmnf9agBXMCdAtUelPgg* visionSys = visionSys0Create();

    Mat imgGrayLast;


    for(int currentImageNr=0; currentImageNr<100; currentImageNr++) {
        // read image
        std::string image_path = samples::findFile(convIntToStrLeadingZeros(currentImageNr, 5)+".jpg");
        Mat img = imread(image_path, IMREAD_COLOR);
        if(img.empty())
        {
            std::cout << "Could not read the image: " << image_path << std::endl;
            return 1;
        }

        
        // convert to grayscale
        Mat imgGray2;
        cv::cvtColor(img, imgGray2, cv::COLOR_BGR2GRAY);
        Mat imgGray;
        cv::resize(imgGray2, imgGray, cv::Size(128, 80), cv::INTER_LINEAR); // size is (width, height)
  
        
        if (currentImageNr==0) {
            imgGrayLast = imgGray;
        }

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
        }


        imshow("Display window", img);
        int k = waitKey(0); // Wait for a keystroke in the window

        imgGrayLast = imgGray;
    }

    return 0;
}
