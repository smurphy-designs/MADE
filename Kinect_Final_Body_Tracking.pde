import KinectPV2.*;
import processing.serial.*;

// Kinect variables
KinectPV2 kinect;
PImage depthImage;
PImage bodyTrackImage;

// Grid and sliders variables
int minDepth = 500; // Minimum depth threshold
int maxDepth = 2000; // Maximum depth threshold
int rows = 9;
int cols = 8;
int tileWidth, tileHeight;

// Smoothing variables
int smoothingFrames = 10; // Number of frames to average
boolean[][] tileStateHistory;
int currentHistoryFrame = 0;

// Sliders
Slider minDepthSlider;
Slider maxDepthSlider;
Slider smoothingSlider;

// Serial communication
Serial myPort;
byte[] byteArray;

void setup() {
  size(1024, 768); // Larger window to show more debug info

  // Initialize Kinect with explicit feature enabling
  kinect = new KinectPV2(this);
  
  kinect.enableDepthImg(true);
  kinect.enableColorImg(true);
  kinect.enableInfraredImg(true);
  kinect.enableBodyTrackImg(true);
  
  kinect.enableSkeletonColorMap(true);
  
  kinect.init();

  // Calculate tile size
  tileWidth = 512 / cols; // Kinect resolution for grid
  tileHeight = 424 / rows;

  // Initialize tile state history
  tileStateHistory = new boolean[smoothingFrames][rows * cols];

  // Initialize sliders BELOW the images
  minDepthSlider = new Slider(50, 550, 200, 20, 0, 4500, 500);
  maxDepthSlider = new Slider(50, 650, 200, 20, 0, 4500, 2000);
  smoothingSlider = new Slider(350, 550, 200, 20, 1, 10, 3);

  // Serial communication (optional, comment out if not using)
  try {
    String portName = Serial.list()[0]; // Use the first available port
    myPort = new Serial(this, portName, 9600);
  } catch (Exception e) {
    println("Serial port error: " + e.getMessage());
    myPort = null;
  }

  // Initialize byte array for serial communication
  byteArray = new byte[rows];

  frameRate(30);
}

void draw() {
  background(50); // Dark gray background

  // Update slider values
  minDepth = (int) minDepthSlider.getValue();
  maxDepth = (int) maxDepthSlider.getValue();
  smoothingFrames = (int) smoothingSlider.getValue();

  // Resize history array if smoothing frames changed
  if (tileStateHistory.length != smoothingFrames) {
    tileStateHistory = new boolean[smoothingFrames][rows * cols];
  }

  // Get raw depth and body track data from Kinect
  int[] rawDepth = kinect.getRawDepthData();
  int[] rawBodyTrack = kinect.getRawBodyTrack();
  
  bodyTrackImage = kinect.getBodyTrackImage();
  depthImage = kinect.getDepthImage();

  // Display debug images
  if (depthImage != null) {
    image(depthImage, 0, 0, 512, 424);
  }
  
  if (bodyTrackImage != null) {
    image(bodyTrackImage, 512, 0, 512, 424);
  }

  // Attempt to display grid and send serial
  if (rawDepth != null && rawBodyTrack != null) {
    displayGridAndSendSerial(rawDepth, rawBodyTrack);
  }

  // Display sliders and text
  fill(255);
  textSize(20);
  text("Depth Controls", 50, 520);

  textSize(14);
  minDepthSlider.display("Min Depth");
  text(minDepth + " mm", 270, 560);

  maxDepthSlider.display("Max Depth");
  text(maxDepth + " mm", 270, 660);

  smoothingSlider.display("Smoothing Frames");
  text(smoothingFrames + " frames", 570, 560);

  fill(255);
  textSize(12);
  text("Body Tracking Debug Info", 530, 500);
  text("Depth Image: " + (depthImage != null), 530, 520);
  text("Body Track Image: " + (bodyTrackImage != null), 530, 540);
}

void displayGridAndSendSerial(int[] rawDepth, int[] rawBodyTrack) {
  // Find the most prominent body
  int primaryBodyId = findPrimaryBodyId(rawBodyTrack);

  // Current frame's tile states
  boolean[] currentFrameTileStates = new boolean[rows * cols];

  for (int row = 0; row < rows; row++) {
    byte rowByte = 0; // Initialize byte for this row
    for (int col = 0; col < cols; col++) {
      int x1 = col * tileWidth;
      int y1 = row * tileHeight;

      // Get average depth for the tile
      float avgDepth = getTileDepth(rawDepth, x1, y1, tileWidth, tileHeight);

      // Check body presence in this tile for the primary body
      boolean bodyInTile = checkBodyInTileSingleBody(rawBodyTrack, x1, y1, tileWidth, tileHeight, primaryBodyId);

      // Check if the tile is within depth range
      boolean inRange = (avgDepth >= minDepth && avgDepth <= maxDepth);

      // Combine with body detection
      boolean currentTileState = inRange && bodyInTile;

      // Store current tile state
      currentFrameTileStates[row * cols + col] = currentTileState;

      // Determine final state after smoothing
      boolean smoothedTileState = smoothTileState(row * cols + col, currentTileState);

      if (smoothedTileState) {
        fill(0); // Black for smoothed tile state
        rowByte |= (1 << col); // Set corresponding bit
      } else {
        fill(255); // White for other conditions
      }

      stroke(100); // Tile borders
      rect(x1, y1, tileWidth, tileHeight);
    }
    byteArray[row] = rowByte; // Store row byte
  }

  // Update tile state history
  tileStateHistory[currentHistoryFrame] = currentFrameTileStates;
  currentHistoryFrame = (currentHistoryFrame + 1) % smoothingFrames;

  // Send all bytes over serial (optional)
  if (myPort != null) {
    myPort.write(byteArray);
    delay(50); // Small delay for serial communication stability
  }
}

int findPrimaryBodyId(int[] rawBodyTrack) {
  // Count body pixels for each body ID
  int[] bodyPixelCounts = new int[7]; // 0-6 are valid body IDs
  
  for (int bodyPixel : rawBodyTrack) {
    if (bodyPixel >= 0 && bodyPixel <= 6) {
      bodyPixelCounts[bodyPixel]++;
    }
  }
  
  // Find the body ID with the most pixels
  int primaryBodyId = -1;
  int maxPixels = 0;
  for (int i = 0; i < bodyPixelCounts.length; i++) {
    if (bodyPixelCounts[i] > maxPixels) {
      maxPixels = bodyPixelCounts[i];
      primaryBodyId = i;
    }
  }
  
  return primaryBodyId;
}

boolean checkBodyInTileSingleBody(int[] rawBodyTrack, int x1, int y1, int tileWidth, int tileHeight, int primaryBodyId) {
  if (primaryBodyId == -1) return false;
  
  for (int y = y1; y < y1 + tileHeight && y < 424; y++) {
    for (int x = x1; x < x1 + tileWidth && x < 512; x++) {
      int index = y * 512 + x;
      if (index < rawBodyTrack.length) {
        // Check if any pixel in the tile matches the primary body ID
        if (rawBodyTrack[index] == primaryBodyId) {
          return true;
        }
      }
    }
  }
  return false;
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

boolean smoothTileState(int tileIndex, boolean currentState) {
  // Count how many frames in history show this tile as active
  int activeFrameCount = 0;
  for (int frame = 0; frame < smoothingFrames; frame++) {
    if (tileStateHistory[frame][tileIndex]) {
      activeFrameCount++;
    }
  }

  // Require a majority of frames to confirm a state change
  return activeFrameCount >= ceil(smoothingFrames / 2.0);
}

// Slider class definition
class Slider {
  float x, y, w, h;
  float minValue, maxValue, value;
  boolean dragging = false;

  // Constructor with 7 parameters (int x, int y, int w, int h, int minValue, int maxValue, int defaultValue)
  Slider(int x, int y, int w, int h, int minValue, int maxValue, int defaultValue) {
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
  minDepthSlider.mousePressed();
  maxDepthSlider.mousePressed();
  smoothingSlider.mousePressed();
}

void mouseReleased() {
  minDepthSlider.mouseReleased();
  maxDepthSlider.mouseReleased();
  smoothingSlider.mouseReleased();
}

void mouseDragged() {
  minDepthSlider.mouseDragged();
  maxDepthSlider.mouseDragged();
  smoothingSlider.mouseDragged();
}
