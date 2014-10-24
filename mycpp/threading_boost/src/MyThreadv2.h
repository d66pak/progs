/*
 * MyThreadv2.h
 *
 *  Created on: Dec 29, 2013
 *      Author: dtelkar
 */

#ifndef MYTHREADV2_H_
#define MYTHREADV2_H_

#include <boost/thread.hpp>

class MyThreadv2 {
public:
    MyThreadv2(int mId);
    MyThreadv2(const MyThreadv2 &ref);
    virtual ~MyThreadv2();
    void start();
    /**
     * run() can be a virtual/pure virtual function so, that it can be overriden
     * for simplicity making it as non virtual
     */
    void run();
    void operator()();
    void join();
private:

    /**
     * NOTE:
     * Thread default ctor creates thread in invalid state
     * so, there is no need of thread ptr
     */
    boost::thread mThread;
    int mId;
    bool mInit;
};

#endif /* MYTHREADV2_H_ */
