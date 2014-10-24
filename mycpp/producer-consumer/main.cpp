#include <iostream>
#include "producer.h"
#include "consumer.h"
#include <boost/thread.hpp>

using namespace std;

int main()
{
	cout << boost::thread::hardware_concurrency() << " processors/cores detected" << endl;

	int producerCount = 0, consumerCount = 0;

	cout << "Enter number of producers: ";
	cin >> producerCount;
	// cout << endl;

	cout << "Enter number of consumers: ";
	cin >> consumerCount;
	// cout << endl;

	cout << "Press enter to stop" << endl;

	SynchronizedQueue<string> syncQ;

	boost::thread_group producersGrp;
	boost::thread_group consumerGrp;

	for (int i = 0; i < producerCount; ++i) {

		Producer p(i, &syncQ);
		producersGrp.create_thread(p);
	}

	for (int i = 0; i < consumerCount; ++i) {

		Consumer c(i, &syncQ);
		consumerGrp.create_thread(c);
	}

	getchar(); getchar();

	producersGrp.interrupt_all();
	consumerGrp.interrupt_all();

	producersGrp.join_all();
	consumerGrp.join_all();

	return 0;
}