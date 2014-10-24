#include <iostream>
#include <boost/tokenizer.hpp>
#include <boost/algorithm/string.hpp>

using namespace std;
using namespace boost::algorithm;

string mytrim(const string& input, const string& whitespace = " \t")
{
  if (input.empty()) {

    return string("");
  }

  string::size_type start = input.find_first_not_of(whitespace);
  string::size_type end = input.find_last_not_of(whitespace);
  return input.substr(start, end - start + 1);
}

int main()
{
  cout << "Hello Boost Tokenizer" << endl;

  string toTokenize("web123, web234, web567 ,web894,\tweb937\t\n ");

  typedef boost::tokenizer<boost::char_separator<char> > tokenizer;
  boost::char_separator<char> sep(",");
  tokenizer tokens(toTokenize, sep);

  for (tokenizer::iterator it = tokens.begin(); it != tokens.end(); ++it) {

    cout << "|" << *it << "|" << endl;

    string temp(*it);
    trim(temp);
    cout << "|" << temp << "|" << endl;

    
    cout << "|" << mytrim(*it, " \t\n") << "|" << endl;
  }

  return 0;

}
