#ifndef TAILFILE_H_INCLUDED
#define TAILFILE_H_INCLUDED

#include <cstdio>
#include <iostream>
#include <fstream>
#include <stack>
#include <cstring>
#include <string>

using namespace std;

class TailFile {

private:

    string file_;
    ifstream fs_;
    int blockSize_;
    //streampos pos_; test
    stack<string> lineCache_;
	char *buf_;


public:
    streampos pos_;
	TailFile();
    TailFile(string file); 
    bool getLine(string &line); 
    void bufferLines();

};

#endif // TAILFILE_H_INCLUDED
