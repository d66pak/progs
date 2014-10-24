/*
 * ThreadInteruption.h
 *
 *  Created on: Dec 27, 2013
 *      Author: dtelkar
 */

#ifndef THREADINTERUPTION_H_
#define THREADINTERUPTION_H_

#include "MyThread.h"
#include <boost/thread/mutex.hpp>

class ThreadInterruption : public MyThread{
public:
    ThreadInterruption();
    virtual ~ThreadInterruption();
    void stop();
    virtual void run();
private:
    boost::mutex mMutex;

};

#endif /* THREADINTERUPTION_H_ */
