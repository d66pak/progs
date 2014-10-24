/*
 * BasicThread.h
 *
 *  Created on: Dec 26, 2013
 *      Author: dtelkar
 */

#ifndef BASICTHREAD_H_
#define BASICTHREAD_H_

void globalWorker();
void globalWorkerWithId(int id);
void globalInterruptWorkerWithId(int id);

class BasicThread {
public:
    BasicThread(int id);
    virtual ~BasicThread();
    void operator()();
    void classMethod(std::string name);
    static void staticWorker();
private:
    int mId;
};

#endif /* BASICTHREAD_H_ */
