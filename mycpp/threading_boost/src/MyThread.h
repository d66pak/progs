/*
 * MyThread.h
 *
 *  Created on: Dec 27, 2013
 *      Author: dtelkar
 */

#ifndef MYTHREAD_H_
#define MYTHREAD_H_

#include <boost/shared_ptr.hpp>
#include <boost/thread.hpp>

class MyThread {
public:
    MyThread();
    virtual ~MyThread();
    virtual void run() = 0;
    void start();
    void join();
    void interrupt();
protected:
    boost::shared_ptr<boost::thread> mThreadPtr;
};

#endif /* MYTHREAD_H_ */
