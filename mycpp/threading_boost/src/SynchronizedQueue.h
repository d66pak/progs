/*
 * SynchronizedQueue.h
 *
 *  Created on: Dec 27, 2013
 *      Author: dtelkar
 */

#ifndef SYNCHRONIZEDQUEUE_H_
#define SYNCHRONIZEDQUEUE_H_

#include <queue>
#include <boost/thread/mutex.hpp>
#include <boost/thread/condition_variable.hpp>

/**
 * Thread safe queue
 * Also know as passive object
 */
template<typename T>
class SynchronizedQueue {
public:
    SynchronizedQueue() {}
    virtual ~SynchronizedQueue() {}

    void push(const T& elem) {

        /**
         * There is no limit to queue so, no need of any condition variable to
         * wait until there is space in the queue
         */

        boost::mutex::scoped_lock lock(mMutex);

        mQueue.push(elem);

        mReadWriteCond.notify_one();
    }

    T pop() {

        boost::mutex::scoped_lock lock(mMutex);
        if (mQueue.empty()) {

            while (mQueue.empty()) {

                // wait until queue is not empty
                mReadWriteCond.wait(lock);
            }
        }

        // Now queue is not empty, pop element
        T temp = mQueue.front();
        mQueue.pop();
        return temp;
    }

private:
    std::queue<T> mQueue;
    boost::mutex mMutex;
    boost::condition_variable mReadWriteCond;
};

#endif /* SYNCHRONIZEDQUEUE_H_ */
