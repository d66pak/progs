#ifndef __SYNC_QUEUE_H__
#define __SYNC_QUEUE_H__

#include <boost/thread.hpp>
#include <boost/utility.hpp>
#include <queue>

template <typename T>
class SynchronizedQueue : public boost::noncopyable
{
public:

	SynchronizedQueue() {}
	~SynchronizedQueue() {}

	void push(const T& elem);
	T pop();

private:

	boost::mutex mutex_;
	boost::condition_variable condVar_;
	std::queue<T> syncQ_;
};

template <typename T>
void SynchronizedQueue<T>::push(const T& elem)
{
	// Acquire mutex
	boost::mutex::scoped_lock lock(mutex_);
	syncQ_.push(elem);
	condVar_.notify_one();
}

template <typename T>
T SynchronizedQueue<T>::pop()
{
	boost::mutex::scoped_lock lock(mutex_);

	if (syncQ_.empty()) {

		condVar_.wait(lock);
	}

	T temp(syncQ_.front());
	syncQ_.pop();
	return temp;
}

#endif