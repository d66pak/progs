#include <iostream>
#include <netdb.h>
#include <netinet/in.h>
#include <arpa/inet.h>

using namespace std;

int main(int argc, char *argv[])
{
  if (argc < 2) {
    return 0;
  }

  in_addr inaddr;
  in_addr_t inadt = inet_addr(argv[1]);
  hostent *remoteHost = gethostbyaddr(&inadt, 4, AF_INET);
  cout << "h_name: " << remoteHost->h_name << endl;


  inaddr.s_addr = inet_addr(argv[1]);
  if (inaddr.s_addr != INADDR_NONE) {
    hostent *remoteHost = gethostbyaddr(&inaddr, 4, AF_INET);
    if (remoteHost != NULL) {
    cout << "h_name: " << remoteHost->h_name << endl;
    for (char **aliases = remoteHost->h_aliases; *aliases != NULL; ++aliases) {
      cout << "aliase: " << *aliases << endl;
    }
    cout << (char *) &inaddr << endl;
    }
  }

  return 0;
}
