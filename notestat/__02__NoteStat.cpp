#include "NoteStat.h"
#include <fstream>
#include <iterator>
#include <algorithm>
#include <netdb.h>
#include <netinet/in.h>
#include <arpa/inet.h>

static const int MAX_EMAIL_LEN = 256;
//static const char UPDATE_FILE[] = "/home/y/logs/status_notification/update";
static const char UPDATE_FILE[] = "myupdate";
const string USER("USER");
const string MODULE("MODULE");
const string STATUS("STATUS");
const string FARM("FARM");

UserInfo::UserInfo(string &line) {

  //cout << "DEBUG: UserInfo: " << line << endl;

  char *buf = new char[line.length() + 1];
  strcpy(buf, line.c_str());
  char *ch1 = strchr(buf, '|');
  char* ch2 = strchr(ch1+1, '|');

  // user
  ch1++;
  *ch2 = '\0';
  user = ch1;
  //cout << "DEBUG: UserInfo:user " << user << endl;
  ch1 = ch2+1;
  ch2 = strchr(ch1, '|');
  *ch2 = '\0';

  //Module
  module = ch1;
  //cout << "DEBUG: UserInfo:module " << module << endl;
  ch1 = ch2+1;
  ch1 = strchr(ch1, '|');
  ch1++;
  ch2 = strchr(ch1, '|');
  *ch2 = '\0';

  // Status
  status = ch1;
  ch1 = strchr(ch2+1, '|');
  ch1++;
  ch1 = strchr(ch1, '|');
  ch2 = strchr(ch1+1, '|');
  ch1++;
  *ch2 = '\0';
  if(ch1 != ch2) {

    faultStr = ch1;

  }

  ch1 = strchr(ch2+1, '|');
  ch1++;
  ch1 = strtok(ch1, "|");
  ts = atol(ch1);
  //cout << "DEBUG: UserInfo:ts " << ts << endl;
  // Farm
  ch1 = strtok(NULL, "|");
  farm = ch1;
  //cout << "DEBUG: UserInfo:farm " << farm << endl;

  //cout << "DEBUG: " << "user: " << user << "module "
  //<< module << "status " << status << "faultStr "
  //<< faultStr << "ts " << ts << "farm " << farm << endl;

  delete []buf;

}

void UserInfo::setFarmHostName()
{
  in_addr_t inaddr = inet_addr(farm.c_str());
  hostent *host = gethostbyaddr((char *)&inaddr, 4, AF_INET);
  string hostName;
  if (host) {
    hostName = host->h_name;
  }
  farmHostName = hostName;
}

ostream& operator<<(ostream& out, const UserInfo& u) {
  out << "|" << u.user << "|" << u.module << "|" << u.status << "|"
    << u.faultStr << "|" << u.ts << "|" << u.farm << "|"
    << u.farmHostName << "|" << endl;
}


// Parse cmd line args
NoteStat::NoteStat(int argc,char **argv) :
  startTime_(0), endTime_(0), hours_(0), count_(false),
  tf_(UPDATE_FILE), sortField_(kFldSTime)
{
  //cout << "DEBUG: Into NoteStat";
  //cout << "DEBUG: NoteStat:: loaded tailfile pos = " <<  tf_.pos_ << endl;

  for(int c = 1; c < argc; c++) {

    char *ch = argv[c];
    //cout << "\nDEBUG: cmd arg is " << ch << endl;
    if(*ch != '-') {

      usage();
      string err = "Invalid command line args: "; 
      throw err + argv[c];;

    }

    ch++;
    if(*ch != 'c' && *ch != 'C') {

      if(c == argc) {

        usage();
        string err = "Invalid command line args: "; 
        throw err + argv[c];;

      }

    }

    switch(*ch) {

      case 's':
      case 'S':
        ch = argv[++c];
        startTime_ = atol(ch);
        break;


      case 'e':
      case 'E':
        ch = argv[++c];
        endTime_ = atol(ch);
        break;

      case 'h':
      case 'H':
        ch = argv[++c];
        hours_ = atoi(ch);
        break;

      case 'c':
      case 'C':
        count_ = true;
        break;

      case 'm':
      case 'M':
        while (((ch = argv[++c]) != NULL ) && *ch != '-') {
          module_.push_back(ch);
        }
        if((ch != NULL) && (*ch == '-')) { c--; }
        break;

      case 'o':
      case 'O':
        while ((ch = argv[++c]) != NULL && *ch != '-') {
          string status(ch);
          transform (status.begin(), status.end(),
              status.begin(), ::toupper);
          statusList_.push_back(status);
        }
        if((ch != NULL) && (*ch == '-')) { c--; }
        break;

      case 'u':
      case 'U':
        ch = argv[++c];
        if (strchr(ch, '@')) {
          // List of email ids
          do {
            userList_.insert(ch);
          } while ((ch = argv[++c]) != NULL && *ch != '-');
          if (ch != NULL && *ch == '-') {
            --c;
          }
        }
        else {
          // User file 
          fillUserList(ch);
        }
        /*
           cout << "DEBUG: userList_ contents:" << endl;
           copy( userList_.begin(), userList_.end(),
           ostream_iterator<string>(cout, " "));
           cout << endl;
           */
        break;

      case 'g':
      case 'G':
        ch = argv[++c];
        setSortField(ch);
        uicp_.reset(new UserInfoContainer(UserInfoSort(sortField_)));
        break;

      case 'f':
      case 'F':
        faultStr_ = argv[++c]; 
        transform (faultStr_.begin(), faultStr_.end(),
            faultStr_.begin(), ::tolower);
        break;

      default:
        usage();
        string err = "Invalid command line args: "; 
        throw err + argv[c];
    }
  } // end for

  if(startTime_ == 0) {
    string err("Invalid command line args: ");
    if (endTime_ == 0 && hours_ == 0) {
      err += "startTime missing";
    }
    else if (endTime_ == 0 || hours_ == 0) {
      err += "endTime or hours is missing";
    }
    usage();
    throw err;
  }
  else {
    if (hours_ != 0) {
      string err("Cannot specify hours along with startTime");
      usage();
      throw err;
    }
  }
}


void NoteStat::print()
{
  int users = 0;
  string line;

  while(tf_.getLine(line)) {
    //cout << "DEBUG: LINE: " << line << endl;

    UserInfo u(line);
    // Stop looking for more users
    if(u.ts < startTime_) break;

    if(applyFilters(u)) {
      // Only display count
      if (count_) {
        users++;
      }
      else {
        // Set the farm host name
        u.setFarmHostName();
        if (sortField_ == kFldSTime) {
          cout << u;
        }
        else {
          // Sorting will be done while inserting
          UserInfoPtr uip(new UserInfo(u));
          uicp_->insert(uip);
        }
      }
    }

  } // end while

  if (count_) {
    cout << "COUNT: " << users << endl;
  }
  else if (sortField_ != kFldSTime) {
    UserInfoContainer::iterator it;
    for (it = uicp_->begin(); it != uicp_->end(); ++it) {
      cout << **it;
    }
  }
}


bool NoteStat::applyFilters(const UserInfo &u) {
  //cout << "DEBUG: applyFilters " << endTime_ << " " << u.ts <<  endl;
  // endTime filter
  if( (endTime_ > 0) && (u.ts > endTime_) ) { return false; }

  //cout << "DEBUG: applyFilters " << userList_.size() << " " << u.user << endl;
  // User filter
  if (!userList_.empty() && userList_.end() == userList_.find(u.user)) {
    return false;
  }

  //cout << "DEBUG: applyFilters " << statusList_.size() << " " << u.status << endl;
  // Status filter
  if (!statusList_.empty() &&
      statusList_.end() == find(statusList_.begin(), statusList_.end(), u.status)) {

    return false;
  }

  //cout << "DEBUG: applyFilters " <<  module_.size() << " " << u.module << endl;
  // Module filter
  bool foundModule = false;
  for(unsigned int i = 0; i < module_.size(); i++) {

    if(module_[i] == u.module) { foundModule = true; break; }
  }

  if(!foundModule && (module_.size() > 0) ) return false;

  // Fault string
  if (!faultStr_.empty()) {
    string str(u.faultStr);
    transform (str.begin(), str.end(),
        str.begin(), ::tolower);
    if (string::npos == str.find(faultStr_)) {
      return false;
    }
  }

  //cout << "DEBUG: applyFilters " <<  "done" << endl;

  return true;
}


void NoteStat::fillUserList(const char* userFile)
{
  ifstream uf(userFile);
  if (!uf) {
    throw "Unable to open file: " + string(userFile);
  }

  char buf[MAX_EMAIL_LEN];
  while (uf.getline(buf, MAX_EMAIL_LEN)) {
    if (strchr(buf, '@')) {
      userList_.insert(buf);
    }
  }

  uf.close();
}


void NoteStat::setSortField(const string& type)
{
  if (type == USER) {
    sortField_ = kFldUser;
  }
  else if (type == MODULE) {
    sortField_ = kFldModule;
  }
  else if (type == STATUS) {
    sortField_ = kFldStatus;
  }
  else if (type == FARM) {
    sortField_ = kFldFarm;
  }
  else {
    sortField_ = kFldSTime;
  }
}


void NoteStat::usage() {
  cout << "notestat - Filters the update logs based on options provided" << endl << endl;
  cout << "notestat -s startTime [options]" << endl << endl;
  cout << "notestat -e endTime -h hrs [options]" << endl << endl;

  cout << "Options:" << endl << endl;
  cout << "-s startTime" << endl;
  cout << "start time" << endl << endl;

  cout << "-e endTime" << endl;
  cout << "end time" << endl << endl;

  cout << "-h hrs" << endl;
  cout << "hours before current local time" << endl;
  cout << "like: -h 50" << endl << endl;

  cout << "-c" << endl;
  cout << "outputs the count of records" << endl << endl;

  cout << "-m module" << endl;
  cout << "list of modules separated by space" << endl;
  cout << "like: -m module1 module2" << endl << endl;

  cout << "-o S|R|F" << endl;
  cout << "status code or list of status codes separated by space" << endl;
  cout << "like: -o S  (or)" << endl;
  cout << "      -o S R" << endl << endl;

  cout << "-u <user_file>/<user_list>" << endl;
  cout << "user_file - name of file having list of user email-ids. Each email-id on separate line" << endl;
  cout << "user_list - list of user email-ids separated by single space" << endl;
  cout << "like: -u userListFile.txt   (or)" << endl;
  cout << "      -u user1@abc.com user2@abc.com" << endl << endl;

  cout << "-g USER/MODULE/STATUS/FARM" << endl;
  cout << "group result based on a field" << endl << endl;

  cout << "-f \"search_fault_string\"" << endl;
  cout << "outputs the records which have the search_fault_string as part of their fault string" << endl;
  cout << "like: -f \"Max retry limit reached\"" << endl;
  cout << "Note: case insensitive search is performed" << endl << endl;
}


bool UserInfoSort::operator() (const boost::shared_ptr<UserInfo>& u1ptr,
    const boost::shared_ptr<UserInfo>& u2ptr) const
{
  switch (_sortOn) {
    case NoteStat::kFldUser:
      return (u1ptr->user < u2ptr->user);
    case NoteStat::kFldModule:
      return (u1ptr->module < u2ptr->module);
    case NoteStat::kFldStatus:
      return (u1ptr->status < u2ptr->status);
    case NoteStat::kFldFarm:
      return (u1ptr->farmHostName < u2ptr->farmHostName);
    default:
      return (u1ptr->ts < u2ptr->ts);
  }
}

//notestat -s starttime [-e endtime] [-c] [-module <name>] [-status S/F]
int main(int argc, char **argv) {
  NoteStat *ns;

  try { 

    ns = new NoteStat(argc, argv);
  }
  catch(string &err) {

    cout << err << endl;
    exit(0);

  }
  catch(...) {

    cout << "Exception!\n";
    exit(0);
  }

  ns->print();

  return 0;
}
