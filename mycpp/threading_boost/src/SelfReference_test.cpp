/*
 * SelfReference_test.cpp
 *
 *  Created on: Dec 26, 2013
 *      Author: dtelkar
 */

//#define BOOST_TEST_DYN_LINK
#define BOOST_TEST_MODULE self_reference

#include <boost/test/unit_test.hpp>
#include "SelfReference.h"

BOOST_AUTO_TEST_SUITE (basic_thread)

BOOST_AUTO_TEST_CASE (startstop) {
    SelfReference sf;
    sf.start();
    boost::this_thread::sleep(boost::posix_time::seconds(2));
    sf.stop();
}
BOOST_AUTO_TEST_SUITE_END ()

