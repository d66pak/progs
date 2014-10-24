/*
 * Consumer.cpp
 *
 *  Created on: Dec 28, 2013
 *      Author: dtelkar
 */

#include "Consumer.h"

using namespace std;

Consumer::Consumer(int id, SynchronizedQueue<std::string>* queue) :
        mConsumerId(id), mSyncQ(queue) {
}

Consumer::~Consumer() {
}

void Consumer::operator()() {

    while (true) {

        try {

            cout << mSyncQ->pop() << endl;
            boost::this_thread::interruption_point();
        } catch (const boost::thread_interrupted &tie) {

            cout << "Consumer " << mConsumerId << " stopping...";
            break;
        }
    }
}
