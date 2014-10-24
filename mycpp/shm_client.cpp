/**
 * shm_client.cpp
 */

#include <sys/types.h>
#include <sys/ipc.h>
#include <sys/shm.h>
#include <stdio.h>
#include <stdlib.h>
#include <iostream>

#include "shm_com.h"

using namespace std;

int main()
{
  int running = 1;
  void *shared_memory = NULL;
  struct shared_use_st *shared_stuff;
  char buffer[BUFSIZ];
  int shmid;
  key_t key = 5678;

  shmid = shmget(key, sizeof(struct shared_use_st), 0666 | IPC_CREAT);
  if (shmid == -1) {
    cerr << "shmget failed";
    exit (EXIT_FAILURE);
  }

  cout << "shared memory client shmid: " << shmid << endl;

  shared_memory = shmat(shmid, NULL, 0);
  if (shared_memory == (void *)-1) {
    cerr << "shmat failed";
    exit (EXIT_FAILURE);
  }

  cout << "Memory attached at: " << (int)shared_memory << endl;

  struct shared_use_st client_struct;
  shared_stuff = (struct shared_use_st *)shared_memory;

  while (running) {
    while (shared_stuff->written_by_you == 1) {
      sleep(1);
      cout << "Waiting for server..." << endl;
    }
    cout << "Enter some text: ";
    //cin >> buffer;
    //cin >> client_struct.some_text;
    cin >> client_struct.str;
    client_struct.written_by_you = 1;
    
    memcpy(shared_memory, &client_struct, sizeof(struct shared_use_st));
    //strncpy(shared_stuff->some_text, buffer, TEXT_SZ);
    //shared_stuff->written_by_you = 1;

    if (strncmp(buffer, "end", 3) == 0) {
      running = 0;
    }
  }

  if (shmdt(shared_memory) == -1) {
    cerr << "shmdt failed";
    exit (EXIT_FAILURE);
  }

  exit (EXIT_SUCCESS);
}
