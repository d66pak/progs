/*
 * Producer.cpp
 *
 *  Created on: Dec 27, 2013
 *      Author: dtelkar
 */

#include "Producer.h"
#include <sstream>

using namespace std;

Producer::Producer(int id, SynchronizedQueue<string>* queue) :
        mProducerId(id), mSyncQ(queue) {
}

Producer::~Producer() {
}

void Producer::operator()() {

    for (int i = 0; i < 10; ++i) {

        stringstream ss;
        ss << "Producer " << mProducerId << " - data " << i;
        mSyncQ->push(ss.str());
        boost::this_thread::sleep(boost::posix_time::seconds(1));
    }
}

