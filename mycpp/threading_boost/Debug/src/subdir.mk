################################################################################
# Automatically-generated file. Do not edit!
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
CPP_SRCS += \
../src/BasicThread.cpp \
../src/BasicThread_test.cpp \
../src/Consumer.cpp \
../src/MyThread.cpp \
../src/MyThreadv2.cpp \
../src/MyThreadv2_test.cpp \
../src/Producer.cpp \
../src/SelfReference.cpp \
../src/SelfReference_test.cpp \
../src/SynchronizedQueue_test.cpp \
../src/ThreadInterruption.cpp \
../src/ThreadInterruption_test.cpp 

OBJS += \
./src/BasicThread.o \
./src/BasicThread_test.o \
./src/Consumer.o \
./src/MyThread.o \
./src/MyThreadv2.o \
./src/MyThreadv2_test.o \
./src/Producer.o \
./src/SelfReference.o \
./src/SelfReference_test.o \
./src/SynchronizedQueue_test.o \
./src/ThreadInterruption.o \
./src/ThreadInterruption_test.o 

CPP_DEPS += \
./src/BasicThread.d \
./src/BasicThread_test.d \
./src/Consumer.d \
./src/MyThread.d \
./src/MyThreadv2.d \
./src/MyThreadv2_test.d \
./src/Producer.d \
./src/SelfReference.d \
./src/SelfReference_test.d \
./src/SynchronizedQueue_test.d \
./src/ThreadInterruption.d \
./src/ThreadInterruption_test.d 


# Each subdirectory must supply rules for building sources it contributes
src/%.o: ../src/%.cpp
	@echo 'Building file: $<'
	@echo 'Invoking: GCC C++ Compiler'
	g++ -I/opt/local/include/ -O0 -g3 -Wall -c -fmessage-length=0 -MMD -MP -MF"$(@:%.o=%.d)" -MT"$(@:%.o=%.d)" -o "$@" "$<"
	@echo 'Finished building: $<'
	@echo ' '


