#ifndef NOTESTAT_H_INCLUDED
#define NOTESTAT_H_INCLUDED

#include <string>
#include <ctime>
#include <cctype>
#include <cstdlib>
#include <vector>
#include <set>
#include <boost/shared_ptr.hpp>
#include "TailFile.h"

using namespace std;

class UserInfo {

  public:
    string user;
    string module;
    char status;
    string faultStr;
    time_t ts;
    string farm;
    string farmHostName;

    UserInfo(string &line); 
    void setFarmHostName();
    friend ostream& operator<< (ostream& out, const UserInfo& u);
};

// Function object for sorting
class UserInfoSort {

  public:
    UserInfoSort(int sortOn):_sortOn(sortOn) {}
    bool operator() (const boost::shared_ptr<UserInfo>& u1ptr,
        const boost::shared_ptr<UserInfo>& u2ptr) const;

  private:
    int _sortOn;
};

class NoteStat {

  public:
    typedef enum {
      kFldSTime = 0,
      kFldUser,
      kFldModule,
      kFldStatus,
      kFldFarm
    } sortType;

    NoteStat() : startTime_(0), endTime_(0) {}
    NoteStat(int argc,char **argv);
    void print();


  private:
    bool applyFilters(const UserInfo &u);
    void fillUserList(const char* userFile);
    void setSortField(const string& type);
    void usage();

  private:
    time_t startTime_, endTime_;
    bool count_;
    vector<string> module_;
    set<string> userList_;
    char status_;
    string currLine_;
    TailFile tf_;
    sortType sortField_;

    // Container to hold sorted UserInfo
    typedef boost::shared_ptr<UserInfo> UserInfoPtr;
    typedef multiset<UserInfoPtr, UserInfoSort> UserInfoContainer;
    typedef boost::shared_ptr<UserInfoContainer> UserInfoContainerPtr;
    UserInfoContainerPtr uicp_;
};


#endif // NOTESTAT_H_INCLUDED

