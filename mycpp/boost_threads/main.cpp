#include <iostream>
#include <boost/thread.hpp>
#include "findsum.h"

using namespace std;

int main()
{
    cout << "Hello World!" << endl;

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

    cout << "Total: " << TOTAL << endl;

    boost::posix_time::ptime end = boost::posix_time::microsec_clock::local_time();

    //cout << "Time taken: " << (end - start) << endl;

    return 0;
}

