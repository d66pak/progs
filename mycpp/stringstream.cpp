#include <iostream>
#include <sstream>

using namespace std;

string createname()
{
  string str("/tmp");
  return str;
}

void createname(stringstream &sstr)
{
  string file("filename");
  sstr << "/tmp/" << file;
}

string createname(int i)
{
  stringstream ss;
  ss << "/tmp/" << i;
  return ss.str();
}

int main()
{

  stringstream infile;
  string str("string-name");
  //infile << createname();
  createname(infile);
  cout << infile.str() << endl;
  return 0;
}
