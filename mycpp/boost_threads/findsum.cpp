#include <boost/thread.hpp>
#include <boost/date_time/posix_time/posix_time.hpp>
#include <boost/cstdint.hpp>
#include "findsum.h"

using namespace std;

boost::mutex mutex;

void FindSum::operator()()
{
    boost::uint64_t sum = 0;
    for (int i = start_; i <= end_; ++i) {

        sum += i;
    }

    boost::mutex::scoped_lock lock(mutex);
    TOTAL += sum;
    cout << "id: " << id_ << " st: " << start_ << " end: " << end_ << " sum: " << sum << " total: " << TOTAL << endl;
}
