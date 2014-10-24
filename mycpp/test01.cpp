#include <iostream>
#include <boost/shared_ptr.hpp>

using namespace std;

int main()
{
  boost::shared_ptr<string> strPtr(new string("Hello world!"));
  cout << "hello world!" << endl;
  cout << *strPtr << endl;
  return 0;

}
