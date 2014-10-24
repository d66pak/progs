#include "producer.h"
#include <sstream>
#include <boost/thread.hpp>

using namespace std;

void Producer::operator()()
{
	int data = 0;

	while (true) {

		stringstream ss;
		ss << "Producer " << id_ << " data: " << data;
		++data;
		q_->push(ss.str());
		cerr << ">>> " << ss.str() << endl;
		boost::this_thread::sleep_for(boost::chrono::milliseconds(30000));
	}
}