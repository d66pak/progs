#include <boost/test/auto_unit_test.hpp>
#include "MyThreadv2.h"

#define BOOST_TEST_MODULE mythread_v2

BOOST_AUTO_TEST_SUITE(basic_thread)

BOOST_AUTO_TEST_CASE(one_start_call_test) {

    MyThreadv2 tv2(1);
    tv2.start();
    tv2.join();
}

BOOST_AUTO_TEST_CASE(two_start_call_test) {

    MyThreadv2 tv2(2);
    tv2.start();
    //tv2.join();

    tv2.start();
    tv2.join();
}

BOOST_AUTO_TEST_SUITE_END()
