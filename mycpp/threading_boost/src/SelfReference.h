/*
 * SelfReference.h
 *
 *  Created on: Dec 27, 2013
 *      Author: dtelkar
 */

#ifndef SELFREFERENCE_H_
#define SELFREFERENCE_H_

#include <boost/thread.hpp>
#include <boost/thread/mutex.hpp>
#include <boost/shared_ptr.hpp>

class SelfReference {
public:
    SelfReference();
    virtual ~SelfReference();
    void stop();
    void start();
    void operator()();
private:
    void doSomeWork();

private:
    boost::shared_ptr<boost::thread> mThread;
    //boost::thread *mThread;
    boost::mutex mMutex;
    bool mStopSignal;
};

#endif /* SELFREFERENCE_H_ */
