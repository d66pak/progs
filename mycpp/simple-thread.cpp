#include <iostream>
#include <boost/thread.hpp>
#include <sstream>

// g++ simple-thread.cpp -lboost_system -lboost_thread

using namespace std;
static string sharedStr;

class Callable {

  public:

    Callable(boost::mutex& m);

    void operator()(const string& threadName);

  private:

    boost::mutex &m_mutex;
};

Callable::Callable(boost::mutex& m): m_mutex(m)
{
}

void Callable::operator()(const string& threadName)
{
  for (int i = 0; i < 5; ++i) {

    //cout << "callable " << i << endl;
    stringstream ss;
    ss << i;
    {
      boost::unique_lock<boost::mutex> lock(m_mutex);
      sharedStr = "Callable thread " + threadName + " " + ss.str();
      cout << sharedStr << endl;
    }
    boost::this_thread::yield();
  }
}

int main()
{
  cout << "---------- Main ------------" << endl;

  boost::mutex m;
  Callable c(m);
  {
    boost::thread t(c, "t");
  }
  // thread represented by t is detached now

  boost::thread t1(c, "t1");
  t1.detach();
  // thread represented by t1 is detached explecitly

  for (int i = 0; i < 5; ++i) {

    //cout << "Main " << i << endl;
    stringstream ss;
    ss << i;
    {
      boost::unique_lock<boost::mutex> lock(m);
      sharedStr = "Main " + ss.str();
      cout << sharedStr << endl;
    }
    // boost::this_thread::yield();
  }

  // t.join();
  sleep (5);
  cout << "---------- Exit ------------" << endl;
  return 0;
}
