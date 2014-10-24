#include <iostream>
#include <boost/thread.hpp>
#include <boost/date_time/posix_time/posix_time.hpp> 
#include <boost/cstdint.hpp>

using namespace std;

boost::mutex mutex;
boost::uint64_t total = 0;

// g++ thread_sum.cpp -lboost_system -lboost_thread

class FindSum
{
public:
	int id_;
	int start_;
    int end_;

public:
	FindSum(int id, int start, int end) : id_(id), start_(start), end_(end) {}

	~FindSum() {}

	void operator()()
	{
		boost::uint64_t sum = 0;
		for (int i = start_; i <= end_; ++i) {

			sum += i;
		}

		boost::mutex::scoped_lock lock(mutex);
		total += sum;
		cout << "id: " << id_ << " st: " << start_ << " end: " << end_ << " sum: " << sum << " total: " << total << endl;
	}
};

int main()
{
	int threadCount = boost::thread::hardware_concurrency();
	// int threadCount = 3;
	cout << threadCount << " processors/cores detected" << endl;

	boost::posix_time::ptime start = boost::posix_time::microsec_clock::local_time();

	int num = 1000000000;
	int size = num / threadCount;
	int rem = num % threadCount;
	int e = 0;
	int s = 0;

    boost::thread_group findSumGrp;

	for (int i = 1; i <= threadCount; ++i) {

        s = e + 1;
        e = s + size - 1;
        if (i == threadCount) {

        	e = s + size + rem - 1;
        }

		FindSum fs(i, s, e);
		findSumGrp.create_thread(fs);
	}

	findSumGrp.join_all();

	cout << "Total: " << total << endl;
	
	boost::posix_time::ptime end = boost::posix_time::microsec_clock::local_time();

	cout << "Time taken: " << (end - start) << endl;
}
