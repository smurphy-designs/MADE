#include <Wire.h>
#include <Adafruit_PWMServoDriver.h>

// Create 5 servo driver objects with different I2C addresses
Adafruit_PWMServoDriver pwm1 = Adafruit_PWMServoDriver(0x40);  // First driver
Adafruit_PWMServoDriver pwm2 = Adafruit_PWMServoDriver(0x41);  // Second driver
Adafruit_PWMServoDriver pwm3 = Adafruit_PWMServoDriver(0x43);  // Third driver
Adafruit_PWMServoDriver pwm4 = Adafruit_PWMServoDriver(0x48);  // Fourth driver
Adafruit_PWMServoDriver pwm5 = Adafruit_PWMServoDriver(0x44);  // Fifth driver

#define SERVOMIN 240     // Minimum pulse length count for 0 degrees
#define TOTAL_SERVOS 72  // Total number of servos
#define BUTTON_PIN 2     // Pin for button input

const int servo_range = 20; // Range of movement for active position

// 9x8 array to store servo offset values (default 0)
int servo_offset[9][8] = {
  { 0, 0, 0, 20, 20, 20, 10, -20 },
  { 10, -10, 20, 20, 30, 20, 20, 20 }, 
  { 0, 10, 0, -10, 10, 20, 20, 0 },
  { 30, 0, 10, -10, 0, 10, 20, 0 },
  { 20, 25, 55, 5, 10, 20, -10, 10 },
  { 10, 20, 0, 0, 0, 55, 10, 10 },
  { 10, 20, 0, 25, 0, -5, 15, 0 }, //# 2 slow??
  { 10, 15, 10, -5, -5, 5, 15, 20 }, 
  { 0, 15, 0, 10, -5, -3, 0, 10 }
};

// Buffer for incoming and previous states
byte incomingData[9] = { 0 };
byte previousData[9] = { 0 };

// Setup function
void setup() {
  Serial.begin(9600);
  pinMode(BUTTON_PIN, INPUT_PULLUP); // Button for resetting to servo_start positions

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

  // Initialize all servos to their servo_start positions
  for (int i = 0; i < 9; i++) {
    for (int j = 0; j < 8; j++) {
      int servoNum = i * 8 + j;              // Servo number in 1D
      int servo_start = SERVOMIN + servo_offset[i][j];  // Calculate starting position
      setServoPosition(servoNum, servo_start);          // Set servo to starting position
      delay(20);  // Small delay for smooth initialization
    }
  }
}

// Set servo position based on its number and desired PWM value
void setServoPosition(int servoNum, int pwmValue) {
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

  driver->setPWM(pin, 0, pwmValue);
}

// Loop function
void loop() {
  // Check if the button is pressed
  if (digitalRead(BUTTON_PIN) == HIGH) {
    Serial.println("Button is pressed");
    // Reset all servos to their `servo_start` positions
    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 8; j++) {
        int servoNum = i * 8 + j;
        int servo_start = SERVOMIN + servo_offset[i][j];
        setServoPosition(servoNum, servo_start);
      }
    }
    delay(500);  // Debounce delay

  }

  // Handle incoming serial data
  if (Serial.available() >= 9) {  // Wait for full 9 bytes
    Serial.readBytes(incomingData, 9);

    // Update servo positions if data has changed
    for (int row = 0; row < 9; row++) {
      if (incomingData[row] != previousData[row]) {
        for (int col = 0; col < 8; col++) {
          int servoIndex = row * 8 + col;
          bool newState = incomingData[row] & (1 << col);
          bool oldState = previousData[row] & (1 << col);

          if (newState != oldState) {
            int servo_start = SERVOMIN + servo_offset[row][col];
            int targetPosition = newState ? servo_start + servo_range : servo_start;
            setServoPosition(servoIndex, targetPosition);
            delay(5);  // Small delay for smooth servo updates
          }
        }
        previousData[row] = incomingData[row];  // Update previous state
      }
    }
  }

  // Clear serial buffer if too much data accumulates
  while (Serial.available() > 9) {
    Serial.read();
  }
}
