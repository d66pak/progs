#ifndef FINDSUM_H
#define FINDSUM_H

#include <iostream>

// g++ thread_sum.cpp -lboost_system -lboost_thread

boost::uint64_t TOTAL = 0;

class FindSum
{
public:
    int id_;
    int start_;
    int end_;

public:
    FindSum(int id, int start, int end) : id_(id), start_(start), end_(end) {}

    ~FindSum() {}

    void operator()();
};

#endif // FINDSUM_H
