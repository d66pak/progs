/*
 * Consumer.h
 *
 *  Created on: Dec 28, 2013
 *      Author: dtelkar
 */

#ifndef CONSUMER_H_
#define CONSUMER_H_

#include "SynchronizedQueue.h"
#include <string>

class Consumer {
public:
    Consumer(int id, SynchronizedQueue<std::string>* queue);
    virtual ~Consumer();
    void operator()();
private:
    int mConsumerId;
    SynchronizedQueue<std::string>* mSyncQ;
};

#endif /* CONSUMER_H_ */
