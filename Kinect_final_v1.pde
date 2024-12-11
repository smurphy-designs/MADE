import KinectPV2.*;
import processing.serial.*;

// Kinect variables
KinectPV2 kinect;
PImage depthImage;

// Grid and sliders variables
float contrast = 1.0; // Default contrast value
int minDepth = 500; // Minimum depth threshold
int maxDepth = 2000; // Maximum depth threshold
int rows = 9;
int cols = 8;
int tileWidth, tileHeight;

// Sliders
Slider contrastSlider;
Slider minDepthSlider;
Slider maxDepthSlider;

// Serial communication
Serial myPort;
byte[] byteArray;

void setup() {
  size(800, 600); // Increased window size to accommodate labels
  
  // Initialize Kinect
  kinect = new KinectPV2(this);
  kinect.enableDepthImg(true);
  kinect.init();
  
  // Calculate tile size
  tileWidth = 512 / cols; // Kinect resolution for grid
  tileHeight = 424 / rows;
  
  // Initialize sliders
  contrastSlider = new Slider(530, 100, 200, 20, 0.1, 3.0, 1.0);
  minDepthSlider = new Slider(530, 200, 200, 20, 0, 4500, 500);
  maxDepthSlider = new Slider(530, 300, 200, 20, 0, 4500, 2000);
  
  // Initialize serial communication
  String portName = "COM5"; // Change to your port name
  myPort = new Serial(this, Serial.list()[0], 9600);

  // Initialize byte array for serial communication
  byteArray = new byte[rows];
  
  frameRate(30);
}

void draw() {
  background(50); // Dark gray background
  
  // Update sliders' values
  contrast = contrastSlider.getValue();
  minDepth = (int) minDepthSlider.getValue();
  maxDepth = (int) maxDepthSlider.getValue();
  
  // Get raw depth data from Kinect
  int[] rawDepth = kinect.getRawDepthData();
  depthImage = kinect.getDepthImage();
  
  // Check for valid depth image
  if (depthImage != null) {
    // Create a copy of the depth image to process
    PImage processedImage = depthImage.copy();
    adjustContrast(processedImage);
    displayGridAndSendSerial(rawDepth); // Updated function to handle serial
    noFill();
    stroke(255);
    rect(0, 0, 512, 424); // Draw border
  }

  // Display sliders
  fill(255);
  textSize(20);
  text("Depth Visualization Controls", 530, 50);
  
  textSize(14);
  contrastSlider.display("Contrast");
  text(nf(contrast, 1, 2), 750, 110);
  
  minDepthSlider.display("Min Depth");
  text(minDepth + " mm", 750, 210);
  
  maxDepthSlider.display("Max Depth");
  text(maxDepth + " mm", 750, 310);
  
  fill(255);
  textSize(12);
  text("Black tiles: Within depth range", 530, 400);
  text("White tiles: Outside depth range", 530, 420);
}

void adjustContrast(PImage img) {
  img.loadPixels();
  for (int i = 0; i < img.pixels.length; i++) {
    float r = red(img.pixels[i]) * contrast;
    float g = green(img.pixels[i]) * contrast;
    float b = blue(img.pixels[i]) * contrast;
    
    r = constrain(r, 0, 255);
    g = constrain(g, 0, 255);
    b = constrain(b, 0, 255);
    
    img.pixels[i] = color(r, g, b);
  }
  img.updatePixels();
}

void displayGridAndSendSerial(int[] rawDepth) {
  for (int row = 0; row < rows; row++) {
    byte rowByte = 0; // Initialize byte for this row
    for (int col = 0; col < cols; col++) {
      int x1 = col * tileWidth;
      int y1 = row * tileHeight;
      float avgDepth = getTileDepth(rawDepth, x1, y1, tileWidth, tileHeight);
      
      if (avgDepth >= minDepth && avgDepth <= maxDepth) {
        fill(0); // Black for depths within range
        rowByte |= (1 << col); // Set corresponding bit
      } else {
        fill(255); // White for depths outside range
      }
      
      stroke(100); // Tile borders
      rect(x1, y1, tileWidth, tileHeight);
    }
    byteArray[row] = rowByte; // Store row byte
  }

  // Send all bytes over serial
  myPort.write(byteArray);
  delay(50); // Small delay for serial communication stability
}

float getTileDepth(int[] rawDepth, int x1, int y1, int tileWidth, int tileHeight) {
  float totalDepth = 0;
  int validPixels = 0;
  
  for (int y = y1; y < y1 + tileHeight && y < 424; y++) {
    for (int x = x1; x < x1 + tileWidth && x < 512; x++) {
      int index = y * 512 + x;
      if (index < rawDepth.length) {
        int depth = rawDepth[index];
        if (depth > 0) { // Only count non-zero depth values
          totalDepth += depth;
          validPixels++;
        }
      }
    }
  }
  
  return validPixels > 0 ? totalDepth / validPixels : 0;
}

// Slider class and mouse interaction functions remain unchanged
class Slider {
  float x, y, w, h;
  float minValue, maxValue, value;
  boolean dragging = false;
  
  Slider(float x, float y, float w, float h, float minValue, float maxValue, float defaultValue) {
    this.x = x;
    this.y = y;
    this.w = w;
    this.h = h;
    this.minValue = minValue;
    this.maxValue = maxValue;
    this.value = defaultValue;
  }

  void display(String label) {
    fill(255);
    textAlign(LEFT, CENTER);
    textSize(14);
    text(label, x, y - 15);
    stroke(150);
    fill(100);
    rect(x, y, w, h);
    float handlePos = map(value, minValue, maxValue, x, x + w);
    fill(0, 255, 0);
    noStroke();
    ellipse(handlePos, y + h / 2, 16, 16);
  }

  float getValue() {
    return constrain(value, minValue, maxValue);
  }

  void mousePressed() {
    if (mouseX >= x && mouseX <= x + w && mouseY >= y - 10 && mouseY <= y + h + 10) {
      dragging = true;
      updateValue();
    }
  }

  void mouseDragged() {
    if (dragging) {
      updateValue();
    }
  }

  void mouseReleased() {
    dragging = false;
  }

  private void updateValue() {
    value = map(constrain(mouseX, x, x + w), x, x + w, minValue, maxValue);
  }
}

void mousePressed() {
  contrastSlider.mousePressed();
  minDepthSlider.mousePressed();
  maxDepthSlider.mousePressed();
}

void mouseReleased() {
  contrastSlider.mouseReleased();
  minDepthSlider.mouseReleased();
  maxDepthSlider.mouseReleased();
}

void mouseDragged() {
  contrastSlider.mouseDragged();
  minDepthSlider.mouseDragged();
  maxDepthSlider.mouseDragged();
}
