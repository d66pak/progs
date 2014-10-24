#include <iostream>
#include <unistd.h>

using namespace std;

static const int HOST_NAME_LEN = 100;

int main()
{
  cout << "gethostname..." << endl;

  char hostName[HOST_NAME_LEN];

  int ret = gethostname(hostName, HOST_NAME_LEN);

  if (!ret) {

    cout << string(hostName) << endl;
  }
  return 0;
}
