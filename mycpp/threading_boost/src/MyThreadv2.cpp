/*
 * MyThreadv2.cpp
 *
 *  Created on: Dec 29, 2013
 *      Author: dtelkar
 */

#include "MyThreadv2.h"

using namespace std;

MyThreadv2::MyThreadv2(int id) :
        mId(id), mInit(false) {
}

MyThreadv2::MyThreadv2(const MyThreadv2& ref) {

    cout << "MyThreadv2 copy ctor called" << endl;
    mId = ref.mId;
    mInit = ref.mInit;
}

MyThreadv2::~MyThreadv2() {
}

/**
 * TODO:
 * What if start() is called more than once by mistake??
 * thread instance is lost!
 * SOLUTION: check flag like init before creating new thread
 */
void MyThreadv2::start() {

    /**
     * NOTE:
     * this ptr has to be passed as argument as this ptr is passes
     * implicitly as 1st parameter to all class methods
     */
//    mThread = boost::thread(boost::ref(*this));
    if (!mInit) {
        mInit = true;
        mThread = boost::thread(boost::bind(&MyThreadv2::run, this));
    } else {

        cout << "Trying to start second time, ignoring..." << endl;
    }
}

void MyThreadv2::join() {

    mThread.join();
}

void MyThreadv2::run() {

    //boost::this_thread::sleep(boost::posix_time::seconds(5));
    cout << "Doing some work in run() method of MyThreadv2 id : " << mId
            << "..." << endl;
}

void MyThreadv2::operator()() {

    cout << "Doing some work in operator() method of MyThreadv2 id : " << mId
            << "..." << endl;
}

