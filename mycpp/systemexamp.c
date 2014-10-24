#include <stdlib.h>
#include <stdio.h>

int mail()
{
  printf("Running ps with system\n");
  system("ps -ax");
  printf("Done.\n");
  exit(0);
}
