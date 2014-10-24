/**
 * shm_com.h
 */

#ifndef SHMCOM_H
#define SHMCOM_H

#include "string.h"

#define TEXT_SZ 2048

struct shared_use_st {
  int written_by_you;
  //char some_text[TEXT_SZ];
  std::string str;
};

#endif
