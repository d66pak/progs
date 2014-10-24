/*
 * Producer.h
 *
 *  Created on: Dec 27, 2013
 *      Author: dtelkar
 */

#ifndef PRODUCER_H_
#define PRODUCER_H_

#include <string>
#include "SynchronizedQueue.h"

class Producer {
public:
    Producer(int id, SynchronizedQueue<std::string>* queue);
    virtual ~Producer();
    void operator()();
private:
    int mProducerId;
    SynchronizedQueue<std::string> *mSyncQ;
};

#endif /* PRODUCER_H_ */
