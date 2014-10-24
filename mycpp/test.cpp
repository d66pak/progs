#include <iostream>
#include <stdlib.h>
#include <stdio.h>
#include <boost/lexical_cast.hpp>

#define ZERO 0
#define ONE 1

using namespace std;

int main()
{
  cout << "Hello world" << endl;
  cout << atoi("23") << endl;
  string str = boost::lexical_cast<string>(900) + " converted using boost!";
  cout << str << endl;
//string str = "some string" + itoa(2);
 // cout << str << endl;
 
  int c;
  cout << "Enter switch case value: ";
  cin >> c;

  switch(c)
  {
    case ZERO:
      {
        cout << "ZERO" << endl;
      }
    case ONE:
      {
        cout << "ONE" << endl;
      }
    default:
      {
        cout << "DEFAULT" << endl;
      }
  }

  string junk("    ");
  cout << "Junk length: " << junk.length() << endl;
  if (junk.empty() ) {

    cout << "Junk is empty" << endl;
  }
  else {

    cout << "Junk is not empty" << endl;
  }

  if (junk.find_first_not_of(" \t\n\r") == string::npos) {

    cout << "Junk is empty/whitespace" << endl;
  }
  return 0;
}
