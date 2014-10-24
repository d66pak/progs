/**
 * shm_server.cpp
 */

#include <sys/types.h>
#include <sys/ipc.h>
#include <sys/shm.h>
#include <stdio.h>
#include <stdlib.h>
#include <iostream>

#include "shm_com.h"

using namespace std;

#define SHMSZ 27

int main()
{
  int running = 1;
  void *shared_memory = NULL;
  struct shared_use_st *shared_stuff;
  int shmid;
  key_t key = 5678;

  srand((unsigned int)getpid());
  shmid = shmget(key, sizeof(struct shared_use_st), IPC_CREAT | 0666);
  if (shmid == -1) {
    cerr << "shmget failed";
    exit (EXIT_FAILURE);
  }

  cout << "shared memory server shmid: " << shmid << endl;

  // Attach
  shared_memory = shmat(shmid, NULL, 0);
  if (shared_memory == (void *)-1) {
    cerr << "shmat failed";
    exit (EXIT_FAILURE);
  }

  cout << "Memory attached at: " << (int)shared_memory << endl;


  // Write into shm
  struct shared_use_st  serv_struct;
  serv_struct.written_by_you = 0;
  memcpy(shared_memory, &serv_struct, sizeof(struct shared_use_st));
  shared_stuff = (struct shared_use_st *)shared_memory;
  //shared_stuff->written_by_you = 0;
  while (running) {
    if (shared_stuff->written_by_you) {
      //cout << "You wrote: " << shared_stuff->some_text << endl;
      cout << "Your string: " << shared_stuff->str << endl;
      sleep(rand() % 4);
      shared_stuff->written_by_you = 0;
      /*
      if (strncmp(shared_stuff->some_text, "end", 3) == 0) {
        running = 0;
      }
      */
      if (shared_stuff->str == "end") {
        running = 0;
      }
    }
  }

  // Detach and delete the shm
  if (shmdt(shared_memory) == -1) {
    cerr << "shmdt failed";
    exit (EXIT_FAILURE);
  }

  if (shmctl(shmid, IPC_RMID, 0) == -1) {
    cerr << "shmctl(IPC_RMID) failed";
    exit (EXIT_FAILURE);
  }

  exit (EXIT_SUCCESS);
}
