#include "consumer.h"
#include <sstream>
#include <boost/thread.hpp>

using namespace std;

void Consumer::operator()()
{
	while (true) {

		stringstream ss;
		ss << "<<< " << id_ << " data: " << q_->pop();
		cerr << ss.str() << endl;

		boost::this_thread::interruption_point();
	}

}