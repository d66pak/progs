/*
 * ThreadInteruption.cpp
 *
 *  Created on: Dec 27, 2013
 *      Author: dtelkar
 */

#include "ThreadInterruption.h"

using namespace std;

ThreadInterruption::ThreadInterruption() {
}

ThreadInterruption::~ThreadInterruption() {
}

void ThreadInterruption::run() {

    boost::mutex::scoped_lock lock(mMutex);

    while (true) {

        try {
            // Disable interruption as sleep() is an interruption point
            boost::this_thread::disable_interruption di;

            cout << "TI - Doing some work..." << endl;
            boost::this_thread::sleep(boost::posix_time::seconds(1));
            cout << "TI - Finished work, checking for stop..." << endl;

            // Enable interruption
            boost::this_thread::restore_interruption ri(di);
            boost::this_thread::interruption_point();
        } catch (const boost::thread_interrupted &tie) {

            cout << "TI - Thread interrupted, stopping the work..." << endl;
            break;
        }
    }
}

void ThreadInterruption::stop() {

    this->interrupt();
}

