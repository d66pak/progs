CC = g++
CFLAGS = -Wall -g -c
OBJS = main.o producer.o consumer.o
TARGET = syncq
LDFLAGS = -lboost_system -lboost_thread -lboost_chrono

all: $(TARGET)

$(TARGET): $(OBJS)	
	$(CC) $(LDFLAGS) $(OBJS) -o syncq

main.o: main.cpp
	$(CC) $(CFLAGS) main.cpp

producer.o: producer.cpp
	$(CC) $(CFLAGS) producer.cpp

consumer.o: consumer.cpp
	$(CC) $(CFLAGS) consumer.cpp

clean:
	rm -rf *.o $(EXE)