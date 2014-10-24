#ifndef NOTESTAT_H_INCLUDED
#define NOTESTAT_H_INCLUDED

#include <string>
#include <ctime>
#include <cctype>
#include <cstdlib>
#include <vector>
#include <set>
#include <fstream>
#include <iterator>
#include <algorithm>
#include "TailFile.h"
using namespace std;

static const int MAX_EMAIL_LEN = 256;
//static const char UPDATE_FILE[] = "/home/y/logs/status_notification/update";
static const char UPDATE_FILE[] = "myupdate";

class UserInfo {

public:
	string user;
	string module;
	char status;
	string faultStr;
	time_t ts;
	string farm;

	UserInfo(string &line) {

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
		status = *ch1;
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

		//cout << "DEBUG: " << "user: " << user << "module " << module << "status " << status << "faultStr " << faultStr << "ts " << ts << "farm " << farm << endl;

		delete []buf;

	}

};

class NoteStat {

	private:
		time_t startTime_, endTime_;
		bool count_;
		vector<string> module_;
                set<string> userList_;
		char status_;		
		string currLine_;
		TailFile tf_;

	public:
		NoteStat() : startTime_(0), endTime_(0) {}
		// Parse cmd line args
		NoteStat(int argc,char **argv) : startTime_(0), endTime_(0), count_(false), status_('\0'),tf_(UPDATE_FILE) { 

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

					case 'c':
					case 'C':
						count_ = true;
						break;

					case 'm':
					case 'M':
						while( ((ch = argv[++c]) != NULL ) && *ch != '-') {
							module_.push_back(ch);
						}
						if((ch != NULL) && (*ch == '-')) { c--; }
						break;

					case 'o':
					case 'O':
						ch = argv[++c];
						status_ = toupper(*ch);
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

					default:
						usage();
						string err = "Invalid command line args: "; 
						throw err + argv[c];

				}



			} // end for

			if(startTime_ == 0) {

				usage();
				string err = "Invalid command line args:  startTime missing";
				throw err;

			}

		}


		void print() {
			
			int users = 0;
			string line;

			while(tf_.getLine(line)) {

				//cout << "DEBUG: LINE: " << line << endl;

				UserInfo u(line);
				// Stop looking for more users
				if(u.ts < startTime_) break;

				if(applyFilters(u)) {

					// Only display count
					if(count_) {
						
						 users++;

					 }
					 else {

						cout << "|" << u.user << "|" << u.module << "|" << u.status << "|" << u.faultStr << "|" << u.ts << "|" << u.farm << "|" << endl;

					}
				}

			}

			if(count_) {
				cout << "COUNT: " << users << endl;
			}

		}


		bool applyFilters(const UserInfo &u) {

			
			//cout << "DEBUG: applyFilters " << endTime_ << " " << u.ts <<  endl;
			// endTime filter
			if( (endTime_ > 0) && (u.ts > endTime_) ) { return false; }

                        //cout << "DEBUG: applyFilters " << userList_.size() << " " << u.user << endl;
                        // User filter
                        if (userList_.end() == userList_.find(u.user)) {
                            return false;
                        }

			//cout << "DEBUG: applyFilters " << status_ << " " << u.status << endl;
			// Status filter
			if(status_ != '\0') {

				if(u.status != status_) { return false; }
			}

			//cout << "DEBUG: applyFilters " <<  module_.size() << " " << u.module << endl;
			// Module filter
			bool foundModule = false;
			for(unsigned int i = 0; i < module_.size(); i++) {

				if(module_[i] == u.module) { foundModule = true; break; }
			}

			if(!foundModule && (module_.size() > 0) ) return false;

			//cout << "DEBUG: applyFilters " <<  "done" << endl;

			return true;

		}


                void fillUserList(const char* userFile)
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


		void usage() {

			cout << "notestat -s startTime [-e endTime] [-c] [-m module] [-o S/R/F] [-u USER_FILE/USER_LIST]" << endl;
                        cout << "USER_FILE - name of file having list of user email-ids. Each email-id on separate line" << endl;
                        cout << "USER_LIST - list of user email-ids separated by single space" << endl;

		}

};

#endif // NOTESTAT_H_INCLUDED
