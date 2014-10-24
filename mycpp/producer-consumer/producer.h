#ifndef __PRODUCER_H__
#define __PRODUCER_H__

#include "SynchronizedQueue.h"

class Producer
{
private:

	int id_;
	SynchronizedQueue<std::string> *q_;

public:

	Producer(int id, SynchronizedQueue<std::string> *q): id_(id), q_(q) {}
	~Producer() {}

	void operator()();
};

#endif
