/*
 * BasicThread_test.cpp
 *
 *  Created on: Dec 26, 2013
 *      Author: dtelkar
 */

#define BOOST_TEST_DYN_LINK
#define BOOST_TEST_MODULE basic_thread

#include <boost/test/unit_test.hpp>
#include <boost/thread.hpp>
#include "BasicThread.h"

BOOST_AUTO_TEST_SUITE(basic_thread)

BOOST_AUTO_TEST_CASE(globalWorker_test) {
    boost::thread t(globalWorker);
    t.join();
}

BOOST_AUTO_TEST_CASE(globalWorkerWithId_test) {
    boost::thread t(boost::bind(globalWorkerWithId, 1));
    t.join();
}

/**
 * NOTE:
 * Parameters to the thread function will be passed automatically
 * No need to use boost::bind
 */
BOOST_AUTO_TEST_CASE(globalWorkerWithIdv2_test) {
    boost::thread t(globalWorkerWithId, 1);
    t.join();
}

BOOST_AUTO_TEST_CASE(classMethod_test) {
//    BasicThread bt(5);
//    boost::thread t(&BasicThread::classMethod, this, "Deepak");
//    t.join();
}

BOOST_AUTO_TEST_CASE(staticWorker_test) {
    boost::thread t(BasicThread::staticWorker);
    t.join();
}
/**
 * NOTE:
 * Functor object is passes by-value to thread
 * Make sure functor objects are copyable
 * If you want to user the same functor object then use boost::ref
 * boost::thread t(boost::ref(bt));
 */
BOOST_AUTO_TEST_CASE(functor_test) {
    BasicThread bt(2);
    boost::thread t(bt);
    t.join();
}

BOOST_AUTO_TEST_CASE(interrupt_test) {
    boost::thread t(boost::bind(globalInterruptWorkerWithId, 3));
    boost::this_thread::sleep(boost::posix_time::seconds(3));
    t.interrupt();
    t.join();
}

BOOST_AUTO_TEST_SUITE_END()

