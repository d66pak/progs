#include <iostream>
#include <stdlib.h>
#include <pthread.h>
#include <boost/shared_ptr.hpp>

using namespace std;

void *thread_a(void *arg)
{
}

void *thread_b(void *arg)
{
}

int main()
{
  boost::shared_ptr<int> common_ptr(new int(0));

  cout << "Creating thread A\n";

  cout << "Creating thread B\n";

  return 0;
}
