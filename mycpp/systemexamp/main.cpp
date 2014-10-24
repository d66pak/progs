#include <iostream>
#include <stdlib.h>
#include <unistd.h>


using namespace std;

int main (int argc, char * const argv[]) {
    cout << "Running ps with system" << endl;
	system("ps -ax");
	cout << "Done" << endl;
    return 0;
}
