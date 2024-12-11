#include <Wire.h>
#include <Adafruit_PWMServoDriver.h>

// Create 5 servo driver objects with different I2C addresses
Adafruit_PWMServoDriver pwm1 = Adafruit_PWMServoDriver(0x40);  // First driver
Adafruit_PWMServoDriver pwm2 = Adafruit_PWMServoDriver(0x41);  // Second driver
Adafruit_PWMServoDriver pwm3 = Adafruit_PWMServoDriver(0x43);  // Third driver
Adafruit_PWMServoDriver pwm4 = Adafruit_PWMServoDriver(0x48);  // Fourth driver
Adafruit_PWMServoDriver pwm5 = Adafruit_PWMServoDriver(0x44);  // Fifth driver

#define SERVOMIN  300  // Minimum pulse length count for 0 degrees
#define TOTAL_SERVOS  72   // Total number of servos

void setup() {
  Serial.begin(9600);
  
  // Initialize all servo drivers
  pwm1.begin();
  pwm2.begin();
  pwm3.begin();
  pwm4.begin();
  pwm5.begin();
  
  // Set PWM frequency for all drivers
  pwm1.setPWMFreq(50);
  pwm2.setPWMFreq(50);
  pwm3.setPWMFreq(50);
  pwm4.setPWMFreq(50);
  pwm5.setPWMFreq(50);

  // Move all servos to minimum position
  for (int i = 0; i < TOTAL_SERVOS; i++) {
    setServoMin(i);
    delay(20);  // Small delay between servo movements
  }
}

// Function to set servo to minimum position across multiple drivers
void setServoMin(int servoNum) {
  // Determine which driver and which pin to use
  Adafruit_PWMServoDriver* driver;
  int pin;

  if (servoNum < 16) {
    driver = &pwm1;
    pin = servoNum;
  } else if (servoNum < 32) {
    driver = &pwm2;
    pin = servoNum - 16;
  } else if (servoNum < 48) {
    driver = &pwm3;
    pin = servoNum - 32;
  } else if (servoNum < 64) {
    driver = &pwm4;
    pin = servoNum - 48;
  } else {
    driver = &pwm5;
    pin = servoNum - 64;
  }

  // Set to minimum position
  driver->setPWM(pin, 0, SERVOMIN);
}

void loop() {
  // Nothing to do in loop
}