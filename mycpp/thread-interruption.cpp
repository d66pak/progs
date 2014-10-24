// g++ thread-interruption.cpp -lboost_system -lboost_thread -lboost_chrono

#include <iostream>
#include <boost/thread.hpp>

using namespace std;

#define BTT boost::this_thread

class Callable
{
  public:

    void operator()();
};

void Callable::operator()()
{
  for (int i = 0; i < 10; ++i) {

    cout << "Callable " << i << endl;
    
    // disable interruption
    //BTT::disable_interruption di;

    

    // Catch interruption

    try {

      for (int j = 100000; j > 0; --j) {

        for (int k = 1000; k > 0; --k)
        {
          // cout << "thread seeeping..." << endl;
          // boost::this_thread::sleep_for(boost::chrono::milliseconds(750));
        }
      }

      boost::this_thread::interruption_point();
      // Set specific interruption point
      // BTT::interruption_point();
      // sleep(1);

      //boost::this_thread::sleep_for(boost::chrono::milliseconds(75));
    }
    catch(const boost::thread_interrupted &ti)
    {

      cout << "Callable interrupted but i caught the exception so it still continues " << endl;
    }
  }
}

class SleepingCallable
{
public:
  void operator()()
  {
    cout << "Thread sleeping..." << endl;
    // boost::this_thread::interruption_point();
    boost::this_thread::sleep_for(boost::chrono::milliseconds(750));
    cout << "Thread awake..." << endl;
  }
};

int main()
{

  Callable c;
  boost::thread t(c);

  SleepingCallable sc;
  // boost::thread st(sc);

  for (int i = 0; i < 10; ++i) {

    cout << "Interrupting thread " << i << endl;
    boost::this_thread::sleep_for(boost::chrono::milliseconds(75));
    t.interrupt();
    // st.interrupt();
  }

  // boost::this_thread::sleep_for(boost::chrono::milliseconds(75));
  // st.interrupt();

  t.join();
  // st.join();
  return 0;
}
