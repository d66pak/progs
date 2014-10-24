/*
 * MyThread.cpp
 *
 *  Created on: Dec 27, 2013
 *      Author: dtelkar
 */

#include "MyThread.h"

#include <boost/chrono/duration.hpp>

MyThread::MyThread() :
        mThreadPtr() {
}

MyThread::~MyThread() {
}

void MyThread::start() {

    if (mThreadPtr == NULL) {

        /**
         * NOTE:
         * this ptr has to be passed as argument as this ptr is passes
         * implicitly as 1st parameter to all class methods
         */
        mThreadPtr.reset(new boost::thread(boost::bind(&MyThread::run, this)));
    } else {

        throw std::runtime_error("multiple start");
    }
}

void MyThread::join() {

    if (mThreadPtr) {

//        while (mThreadPtr->try_join_for(boost::chrono::milliseconds(100))
//                == false) {
//            std::cout << "Calling join on thread..." << std::endl;
//        }
        mThreadPtr->join();
    }
}

void MyThread::interrupt() {

    if (mThreadPtr) {
        mThreadPtr->interrupt();
    }
}

