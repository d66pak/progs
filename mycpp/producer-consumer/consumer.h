#ifndef __CONSUMER_H__
#define __CONSUMER_H__

#include "SynchronizedQueue.h"

class Consumer
{
private:

	int id_;
	SynchronizedQueue<std::string> *q_;

public:

	Consumer(int id, SynchronizedQueue<std::string> *q) : id_(id), q_(q) {}
	~Consumer() {}

	void operator()();
};

#endif