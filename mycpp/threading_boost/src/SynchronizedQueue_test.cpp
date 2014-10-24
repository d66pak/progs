/*
 * SynchronizedQueue_test.cpp
 *
 *  Created on: Dec 27, 2013
 *      Author: dtelkar
 */

#include "SynchronizedQueue.h"
#include "Producer.h"
#include "Consumer.h"

#include <boost/test/auto_unit_test.hpp>
#include <boost/thread/thread.hpp>

using namespace std;

#define BOOST_TEST_MODULE synchronized_queue

BOOST_AUTO_TEST_SUITE(basic_thread)

BOOST_AUTO_TEST_CASE(producer_consumer) {

    SynchronizedQueue<string> syncQ;

    boost::thread_group Producers;
    for (int i = 0; i < 5; ++i) {

        Producer p(i, &syncQ);
        Producers.create_thread(p);
    }

    boost::thread_group Consumers;
    for (int i = 0; i < 5; ++i) {

        Consumer c(i, &syncQ);
        Consumers.create_thread(c);
    }

    // Wait for all the producers to finish
    Producers.join_all();

    // Now stop the consumers
    Consumers.interrupt_all();
    Consumers.join_all();
    boost::this_thread::sleep(boost::posix_time::seconds(10));
}
BOOST_AUTO_TEST_SUITE_END()

