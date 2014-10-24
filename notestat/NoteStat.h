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

/**
 * @class UserInfo
 * @brief Class for storing user info
 */
class UserInfo {

  /**
   * Overloaded operator to print UserInfo class
   * @param out ostream reference
   * @param u UserInfo reference to be printed
   */
  friend ostream& operator<< (ostream& out, const UserInfo& u);

  public:

  /**
   * Fields as written by lca script to update file
   */
  typedef enum {
    kUid = 0,
    kModule,
    kPartner,
    kRetCode,
    kFaultCode,
    kDetail,
    kFaultStr,
    kYSpecific,
    kFarmMsg,
    kRTime,
    kHost
  } lcaFields;

  string user;
  string module;
  string partner;
  string status;
  string faultStr;
  time_t ts;
  string timestamp;
  string farm;
  string farmHostName;

  UserInfo(string &line);

  /**
   * Converts ip address to host name
   */
  void setFarmHostName();

  /**
   * Converts epoch time to string format
   */
  void setLocalTime();
};

/**
 * @class UserInfoSort
 * @brief Function object for sorting/grouping
 */
class UserInfoSort {

  public:
    UserInfoSort(int sortOn):_sortOn(sortOn) {}

    /**
     * Overloaded operator for comparing objects
     * @param u1ptr reference to shared_ptr holding UserInfo object
     * @param u2ptr reference to shared_ptr holding UserInfo object
     */
    bool operator() (const boost::shared_ptr<UserInfo>& u1ptr,
        const boost::shared_ptr<UserInfo>& u2ptr) const;

  private:
    int _sortOn;
};

/**
 * @class NoteStat
 * @brief Main class to process update log
 */
class NoteStat {

  public:
    // Fields on which user can be sorted/grouped
    typedef enum {
      kFldSTime = 0,
      kFldUser,
      kFldModule,
      kFldPartner,
      kFldStatus,
      kFldFarm
    } sortType;

    NoteStat() : startTime_(0), endTime_(0) {}
    NoteStat(int argc,char **argv);

    /**
     * Function to print the user
     */
    void print();


  private:
    /**
     * Selects user based on the filters provided
     * @param u user to check
     */
    bool applyFilters(const UserInfo &u);

    /**
     * Fills the user list from file
     * @param userFile name of file in which user list is stored
     */
    void fillUserList(const char* userFile);

    /**
     * Sets sort field based on the option received
     * @see usage() for valid sort fields
     * @param type sort field type
     */
    void setSortField(const string& type);

    /**
     * Converts time provided as string to epoch time
     * @see usage() for format of date time string
     * @param [in] datetime date time in string format
     * @param [out] epochTime date time in epoch format
     * @return bool true if conversion success else false
     */
    bool toEpoch(const char* datetime, time_t *epochTime);

    /**
     * Prints the usage/help message
     */
    void usage();

  private:
    time_t startTime_, endTime_;
    int hours_;
    bool count_;
    vector<string> module_;
    vector<string> partnerList_;
    set<string> userList_;
    vector<string> statusList_;
    string faultStr_;
    TailFile tf_;
    sortType sortField_;

    // Container to hold sorted UserInfo
    typedef boost::shared_ptr<UserInfo> UserInfoPtr;
    typedef multiset<UserInfoPtr, UserInfoSort> UserInfoContainer;
    typedef boost::shared_ptr<UserInfoContainer> UserInfoContainerPtr;
    UserInfoContainerPtr uicp_;
};


#endif // NOTESTAT_H_INCLUDED

