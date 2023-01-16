// compile with
//    g++ a.cpp -o a `pkg-config --cflags --libs opencv`

#include <opencv2/core.hpp>
#include <opencv2/imgcodecs.hpp>
#include <opencv2/highgui.hpp>
#include <opencv2/imgproc.hpp>
#include <iostream>
using namespace cv;



int main()
{
    std::string image_path = samples::findFile("starry_night.jpg");
    Mat img = imread(image_path, IMREAD_COLOR);
    if(img.empty())
    {
        std::cout << "Could not read the image: " << image_path << std::endl;
        return 1;
    }

    
    // convert to grayscale
    Mat imgGray;
    cv::cvtColor(img, imgGray, cv::COLOR_BGR2GRAY);

    // read pixels
    {
        // i is by column
        // j is by row
        std::vector<double> arr;
        for(int j=0;j<imgGray.rows;j++) {
            for (int i=0;i<imgGray.cols;i++) {
                uchar val0 = imgGray.at<uchar>(j,i);
                arr.push_back(val0/255.0);
            }
        }


    }


    imshow("Display window", img);
    int k = waitKey(0); // Wait for a keystroke in the window
    if(k == 's')
    {
        imwrite("starry_night.png", img);
    }
    return 0;
}
