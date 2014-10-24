/*
 * BasicThread.cpp
 *
 *  Created on: Dec 26, 2013
 *      Author: dtelkar
 */

#include <boost/thread/mutex.hpp>
#include <boost/thread.hpp>
#include "BasicThread.h"

using namespace std;
// Global mutex
boost::mutex MY_IO_MUTEX;

BasicThread::BasicThread(int id) :
        mId(id) {
}

BasicThread::~BasicThread() {
}

void BasicThread::operator ()() {

    boost::mutex::scoped_lock lock(MY_IO_MUTEX);
    cout << "Processing functor with thread id : " << mId << endl;
}

void BasicThread::classMethod(string name) {

    boost::mutex::scoped_lock lock(MY_IO_MUTEX);
    cout << "Processing class method with thread id : " << mId << " and name : "
            << name << endl;
}

void BasicThread::staticWorker() {

    boost::mutex::scoped_lock lock(MY_IO_MUTEX);
    cout << "Processing staticWorker..." << endl;
}

void globalWorker() {
    boost::mutex::scoped_lock lock(MY_IO_MUTEX);
    cout << "Processing globalWorker..." << endl;
}

void globalWorkerWithId(int id) {
    boost::mutex::scoped_lock lock(MY_IO_MUTEX);
    cout << "Processing globalWorker with thread id : " << id << endl;
}

void globalInterruptWorkerWithId(int id) {

    boost::mutex::scoped_lock lock(MY_IO_MUTEX);

    while (true) {

        try {
            // Disable interruption as sleep() is an interruption point
            boost::this_thread::disable_interruption di;

            cout << "Thread " << id << " Doing some work..." << endl;
            boost::this_thread::sleep(boost::posix_time::seconds(1));
            cout << "Thread " << id << " Finished work, checking for stop..."
                    << endl;

            // Enable interruption
            boost::this_thread::restore_interruption ri(di);
            boost::this_thread::interruption_point();
        } catch (const boost::thread_interrupted &tie) {

            cout << "Thread " << id
                    << " Thread interrupted, stopping the work..." << endl;
            break;
        }
    }
}
