#include <Wire.h>
#include <Adafruit_PWMServoDriver.h>

// Define your servo min and max pulse lengths
#define SERVOMIN 150  // Pulse length for 0 degrees
#define SERVOMAX 600  // Pulse length for 180 degrees

// Create an instance of the PCA9685 driver
Adafruit_PWMServoDriver pwm = Adafruit_PWMServoDriver();

void setup() {
  Serial.begin(9600);
  pwm.begin();
  pwm.setPWMFreq(60);  // Set the PWM frequency to 60 Hz for servos
  Serial.println("PCA9685 Servo Test");
}

void loop() {
  // Sweep from 0 to 180 degrees
  for (float angle = 0; angle <= 180; angle += 20) {
    setServoAngle(0, angle); // Move servo 0 to the specified angle
    delay(500); // Wait to see the movement
  }
  
  // Sweep from 180 to 0 degrees
  for (float angle = 180; angle >= 0; angle -= 20) {
    setServoAngle(0, angle);
    delay(500); // Wait to see the movement
  }
}

// Function to set the servo angle
void setServoAngle(uint8_t servo, float angle) {
  // Map the angle to the corresponding pulse width
  int pulseWidth = map(angle, 0, 180, SERVOMIN, SERVOMAX);
  pwm.setPWM(servo, 0, pulseWidth); // Set the PWM signal for the specified servo
}
