/*
 * SelfReference.cpp
 *
 *  Created on: Dec 27, 2013
 *      Author: dtelkar
 */

#include "SelfReference.h"
#include <boost/ref.hpp>

using namespace std;

SelfReference::SelfReference() :
        mThread(), mStopSignal(false) {
}

SelfReference::~SelfReference() {
}

void SelfReference::stop() {

    boost::mutex::scoped_lock lock(mMutex);
    mStopSignal = true;
}

void SelfReference::start() {

    if (mThread == NULL) {

        /**
         * NOTE:
         * this ptr has to be passed as argument as this ptr is passes
         * implicitly as 1st parameter to all class methods
         */
        mThread.reset(new boost::thread(boost::ref(*this)));
    }
}

void SelfReference::operator()() {

    // keep working until stop signal is received
    while (true) {

        // Check if stop signal is received
        {
            boost::mutex::scoped_lock lock(mMutex);
            if (mStopSignal) {
                break;
            }
        }
        doSomeWork();
    }
}

void SelfReference::doSomeWork() {

    cout << "SF - Doing some work..." << endl;
    boost::this_thread::sleep(boost::posix_time::seconds(1));
}
