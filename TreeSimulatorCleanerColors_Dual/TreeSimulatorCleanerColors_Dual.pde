/*
  Tree Simulator and Lighter
  
  1. Simulator: draws squares on the monitor
  2. Lighter: sends data to the lights
  
  7/13/18
  
  API
  
  Python Showrunner sends: pixel, r, g, b
     Showrunner needs to figure out branch mapping
     as well as deconvolving trunks to leds
     pixel is the first led of the 2 doubled leds
 
  Processing handles interpolating between channels (ABF)
     Processing lights the first led
     and uses a lookup array to light the second led
*/

// Simulator screen variables
int SCREEN_SIZE = 700;  // square shaped

// Tree variables
float PIXEL_HEIGHT = 2.2;
float PIXEL_BORDER = 0;
float TOTAL_PIXEL_HEIGHT = PIXEL_HEIGHT * (1 + PIXEL_BORDER);
float PIXEL_WIDTH = 2.94 * TOTAL_PIXEL_HEIGHT;  // intrinsic to the pool noodle
int[] NUM_PIXELS_GEN = {56, 38, 28, 20};
int MAX_GENERATIONS = 3; //number of initial generations
int NUMBER_TRUNKS = 3; //num of 1st gen branches
int DOUBLE_TRUNKS = NUMBER_TRUNKS * 2;
int NUMBER_BRANCHES = 2; // num of later branches

// Timing variables needed to control regular morphing
// Doubled for 2 channels
int SLOWNESS = 20;
int[] delay_time = { 10000, 10000 };  // delay time length in milliseconds (dummy initial value)
long[] start_time = { millis(), millis() };  // start time point (in absolute time)
long[] last_time = { start_time[0], start_time[1] };
short[] channel_intensity = { 255, 0 };  // Off = 0, All On = 255 

// LED variables
int NUM_CHANNELS = 2;  // Dual shows
int TRUNK_LEDS = get_number_trunk_leds();  // 404, only one direction
int FULL_TRUNK_LEDS = TRUNK_LEDS * 2;  // 808, forward and reverse LEDS
int TOTAL_LEDS = TRUNK_LEDS * NUMBER_TRUNKS;
int pixel_counter = 0;
int forward_led_counter = 0;
int[] forward_led_lookup = new int[TOTAL_LEDS];
int[] reverse_led_lookup = new int[TOTAL_LEDS];
short[][][] curr_buffer = new short[NUM_CHANNELS][TOTAL_LEDS][3];
short[][][] next_buffer = new short[NUM_CHANNELS][TOTAL_LEDS][3];
short[][][] morph_buffer = new short[NUM_CHANNELS][TOTAL_LEDS][3];  // blend of curr + next
short[][] interp_buffer = new short[TOTAL_LEDS][3];  // combine two channels here

float[] x_coord = new float[TOTAL_LEDS];
float[] y_coord = new float[TOTAL_LEDS];
float[] z_coord = new float[TOTAL_LEDS];

// Reverse-strand LED lookup table
int[][] reverse_lookup_table = {
  {0, 55, 807, 752},
  {56, 93, 403, 366},
  {94, 121, 229, 202},
  {122, 141, 161, 142},
  {162, 181, 201, 182},
  {230, 257, 365, 338},
  {258, 277, 292, 278},
  {298, 317, 337, 318},
  {404, 441, 751, 714},
  {442, 469, 577, 550},
  {470, 489, 509, 490},
  {510, 529, 549, 530},
  {578, 605, 686, 713},
  {606, 625, 645, 626},
  {646, 665, 685, 666}
};

import com.heroicrobot.dropbit.registry.*;
import com.heroicrobot.dropbit.devices.pixelpusher.Pixel;
import com.heroicrobot.dropbit.devices.pixelpusher.Strip;
import com.heroicrobot.dropbit.devices.pixelpusher.PixelPusher;
import com.heroicrobot.dropbit.devices.pixelpusher.PusherCommand;

import processing.net.*;
import java.util.*;
import java.util.regex.*;

// network vars
int port = 4444;
Server[] _servers = new Server[NUM_CHANNELS];  // For dual shows 
StringBuffer[] _bufs = new StringBuffer[NUM_CHANNELS];  // separate buffers

class TestObserver implements Observer {
  public boolean hasStrips = false;
  public void update(Observable registry, Object updatedDevice) {
    println("Registry changed!");
    if (updatedDevice != null) {
      println("Device change: " + updatedDevice);
    }
    this.hasStrips = true;
  }
}

TestObserver testObserver;

// Physical strip registry
DeviceRegistry registry;
List<Strip> strips = new ArrayList<Strip>();
Strip[] strip_array = new Strip[DOUBLE_TRUNKS];

//
// Controller on the bottom of the screen
//
// Draw labels has 3 states:
// 0:LED number, 1:(x,y) coordinate, and 2:none
int DRAW_LABELS = 2;

boolean UPDATE_VISUALIZER = true;  // turn false for LED-only updates

PFont font_square = createFont("Helvetica", 12, true);

int BRIGHTNESS = 100;  // A percentage

int COLOR_STATE = 0;  // no enum types in processing. Messy

byte R_ = 0;
byte G_ = 1;
byte B_ = 2;

class RGB {
  public short r, g, b;
  
  RGB(short r, short g, short b) {
    this.r = r;
    this.g = g;
    this.b = b;
  }
  
  RGB() {
    this.r = 0;
    this.g = 0;
    this.b = 0;
  }
}

//
// setup
//
void setup() {
  size(SCREEN_SIZE, SCREEN_SIZE + 50); // 50 for controls
  fill(255,255,0);
  
  frameRate(10);
  
  registry = new DeviceRegistry();
  testObserver = new TestObserver();
  registry.addObserver(testObserver);
  prepareExitHandler();
  strips = registry.getStrips();
  
  colorMode(RGB, 255);
  
  initializeColorBuffers();  // Stuff curr/next frames with zeros (all black)
  
  fill_paired_lookup_array();  // Calculate LED pairing
  
  for (int i = 0; i < NUM_CHANNELS; i++) {
    _bufs[i] = new StringBuffer();
    _servers[i] = new Server(this, port + i);
    println("server " + i + " listening: " + _servers[i]);
  }
}


void draw() {
  drawBottomControls();
  pollServer();        // Get messages from python show runner
  update_morph();      // Get messages from python show runner
  interpChannels();    // Interpolate between channels
  if (UPDATE_VISUALIZER) {
    draw_tree();       // Draw the whole tree
  }
  sendDataToLights();  // Dump data into lights
}

//
// draw tree
//
// Draw the tree recursively - draws all pixels at once
// does not use a pixel class
// Merely pulls and shows on screen the pixels
// Does neither interpolation, nor Pixel-Pusher led lighting
// 
void draw_tree() {
   // Go to the center of screen
   translate(SCREEN_SIZE / 2.0, SCREEN_SIZE / 2.0); 
   
   noStroke();
   rectMode(CENTER);
   int led = 0; // a pixel counter
   
   // Rotate and draw each trunk
   for (int trunk = 0; trunk < NUMBER_TRUNKS; trunk++) {
      rotate(TWO_PI / NUMBER_TRUNKS);
      led = draw_pixel_line(0, led);
      translate(0, get_branch_length(0));
      led = draw_branch(1, led);
      translate(0, -get_branch_length(0));
   }
//   for(int i = 0; i < TOTAL_LEDS; i++) { 
//     println(i + ", " + x_coord[i] + ", " + y_coord[i] + ", " + z_coord[i]);
//   }
}

//
// draw branch
//
// Draw branches recursively
//  
int draw_branch(int gen, int led) {
   if (gen > MAX_GENERATIONS) {
     return led;  // ends the recursion
   }
   
   pushMatrix();
   
   rotate(PI + (TWO_PI / (NUMBER_BRANCHES + 1)));
   
   for (int branch = 0; branch < NUMBER_BRANCHES; branch++) {
      led = draw_pixel_line(gen, led);
      translate(0, get_branch_length(gen));
      led = draw_branch(gen + 1, led); //recursion here
      translate(0, -get_branch_length(gen));
      rotate(TWO_PI / 3);  // 120 degrees
   }

   popMatrix();
   
   return led;
}

int draw_pixel_line(int generation, int led) {
  // Draw a line of pixels, length determined by generation
  for (int pixel = 0; pixel < NUM_PIXELS_GEN[generation]; pixel++) {
    fill(color(interp_buffer[led][R_], interp_buffer[led][G_], interp_buffer[led][B_]));
    rect(0, pixel * TOTAL_PIXEL_HEIGHT, PIXEL_WIDTH, PIXEL_HEIGHT);
    led++;
  }
  return led;
}

float get_branch_length(int generation) {
  return NUM_PIXELS_GEN[generation] * TOTAL_PIXEL_HEIGHT;
}

int get_number_trunk_leds() {
  // Calculate the number of unpaired leds in a trunk
  int num_leds = 0;
  int num_branches = 1;
  for (int gen = 0; gen <= MAX_GENERATIONS; gen++) {
    num_leds += (NUM_PIXELS_GEN[gen] * num_branches);
    num_branches *= 2;
  }
  return num_leds;
}

//
// Colors and addressing pixels
//
void initializeColorBuffers() {
  for (int c = 0; c < NUM_CHANNELS; c++) {
    fill_black_one_channel(c);
  }
}

void fill_black_one_channel(int c) {
  for (int i = 0; i < TOTAL_LEDS; i++) {
    for (int j = 0; j < 3; j++) {
      curr_buffer[c][i][j] = 0;
      next_buffer[c][i][j] = 0;
    }
  }
}

void pushColorBuffer(byte c) {
  for (int i = 0; i < TOTAL_LEDS; i++) {
    for (int j = 0; j < 3; j++) {
      curr_buffer[c][i][j] = next_buffer[c][i][j];
    }
  }
}

//
//  Server Routines
//
void pollServer() {
  // Read 2 different server ports into 2 buffers - keep channels separated
  for (int i = 0; i < NUM_CHANNELS; i++) {
    try {
      Client c = _servers[i].available();
      // append any available bytes to the buffer
      if (c != null) {
        _bufs[i].append(c.readString());
      }
      // process as many lines as we can find in the buffer
      int ix = _bufs[i].indexOf("\n");
      while (ix > -1) {
        String msg = _bufs[i].substring(0, ix);
        msg = msg.trim();
        processCommand(msg);
        _bufs[i].delete(0, ix+1);
        ix = _bufs[i].indexOf("\n");
      }
    } catch (Exception e) {
      println("exception handling network command");
      e.printStackTrace();
    }
  }  
}

//
// With DUAL shows: 
// 1. all commands must start with either a '0' or '1'
// 2. Followed by either
//     a. X = Finish a morph cycle (clean up by pushing the frame buffers)
//     b. D(int) = delay for int milliseconds (but keeping morphing)
//     c. I(short) = channel intensity (0 = off, 255 = all on)
//     d. Otherwise, process 4 integers as (i, r,g,b)
//
//
void processCommand(String cmd) {
  if (cmd.length() < 2) { return; }  // Discard erroneous stub characters
  byte channel = (cmd.charAt(0) == '0') ? (byte)0 : (byte)1 ;  // First letter indicates Channel 0 or 1
  cmd = cmd.substring(1, cmd.length());  // Strip off first-letter Channel indicator
  
  if (cmd.charAt(0) == 'X') {  // Finish the cycle
    finishCycle(channel);
  } else if (cmd.charAt(0) == 'D') {  // Get the delay time
    delay_time[channel] = Integer.valueOf(cmd.substring(1, cmd.length())) * SLOWNESS;
  } else if (cmd.charAt(0) == 'I') {  // Get the intensity
    channel_intensity[channel] = Integer.valueOf(cmd.substring(1, cmd.length())).shortValue();
  } else {  
    processPixelCommand(channel, cmd);  // Pixel command
  }
}

// 4 comma-separated numbers for i, r, g, b
Pattern cmd_pattern = Pattern.compile("^\\s*(\\d+),(\\d+),(\\d+),(\\d+)\\s*$");

void processPixelCommand(byte channel, String cmd) {
  Matcher m = cmd_pattern.matcher(cmd);
  if (!m.find()) {
    //println(cmd);
    println("ignoring input for " + cmd);
    return;
  }
  int i = Integer.valueOf(m.group(1));
  int r = Integer.valueOf(m.group(2));
  int g = Integer.valueOf(m.group(3));
  int b = Integer.valueOf(m.group(4));
  
  if (i > TOTAL_LEDS) {
    println("LED index of %d is too large", i);
    return;
  }
  next_buffer[channel][i][R_] = (short)r;
  next_buffer[channel][i][G_] = (short)g;
  next_buffer[channel][i][B_] = (short)b;
//  println(String.format("setting channel %d pixel:%d to r:%d, g:%d, b:%d", channel, i, r, g, b));
}

/////  Routines to interact with the Lights

//
// Interpolate Channels
//
// Interpolate between the 2 channels 
//
void interpChannels() {
  if (!is_channel_active(0)) {
    pushOnlyOneChannel(1);
  } else if (!is_channel_active(1)) {
    pushOnlyOneChannel(0);
  } else {
    float fract = (float)channel_intensity[0] / (channel_intensity[0] + channel_intensity[1]);
//    fract = 0;  // ToDo: Remove!
    morphBetweenChannels(fract);
  }
}

//
// pushOnlyOneChannel - push the morph_channel to the simulator
//
void pushOnlyOneChannel(int channel) {
  RGB rgb = new RGB();  // "pointer" by reference
  
  for (int i = 0; i < TOTAL_LEDS; i++) {
    rgb.r = morph_buffer[channel][i][R_];
    rgb.g = morph_buffer[channel][i][G_];
    rgb.b = morph_buffer[channel][i][B_];
    
    adjColor(rgb);
    
    interp_buffer[i][R_] = rgb.r;
    interp_buffer[i][G_] = rgb.g;
    interp_buffer[i][B_] = rgb.b; 
  }
}

//
// morphBetweenChannels - interpolate the morph_channel on to the simulator
//
void morphBetweenChannels(float fract) {
  RGB rgb = new RGB();  // "pointer" by reference
  
  for (int i = 0; i < TOTAL_LEDS; i++) {
    interp_color(morph_buffer[1][i][R_], morph_buffer[1][i][G_], morph_buffer[1][i][B_],
                 morph_buffer[0][i][R_], morph_buffer[0][i][G_], morph_buffer[0][i][B_], 
                 rgb, fract);
    adjColor(rgb);         
    
    interp_buffer[i][R_] = rgb.r;
    interp_buffer[i][G_] = rgb.g;
    interp_buffer[i][B_] = rgb.b;
  }
}

void interp_color(short r1, short g1, short b1, short r2, short g2, short b2, RGB rgb, float fract) {
  rgb.r = interp(r1, r2, fract);
  rgb.g = interp(g1, g2, fract);
  rgb.b = interp(b1, b2, fract);
}

//
//  Fractional morphing between current and next frame - sends data to lights
//
//  fract is an 0.0 - 1.0 fraction towards the next frame
//
void morph_frame(byte c, float fract) {
  RGB rgb = new RGB();  // "pointer" by reference
  
  for (int i = 0; i < TOTAL_LEDS; i++) {
    interp_color(curr_buffer[c][i][R_], curr_buffer[c][i][G_], curr_buffer[c][i][B_], 
                 next_buffer[c][i][R_], next_buffer[c][i][G_], next_buffer[c][i][B_], rgb, fract);
    
    morph_buffer[c][i][R_] = rgb.r;
    morph_buffer[c][i][G_] = rgb.g;
    morph_buffer[c][i][B_] = rgb.b;
  }
}

// Adjust color for brightness and hue
void adjColor(RGB rgb) {
  colorCorrect(rgb);
  adj_brightness(rgb);
}

void adj_brightness(RGB rgb) {
  rgb.r = (short)(rgb.r * BRIGHTNESS / 100);
  rgb.g = (short)(rgb.g * BRIGHTNESS / 100);
  rgb.b = (short)(rgb.b * BRIGHTNESS / 100);
}

void colorCorrect(RGB rgb) {
  switch(COLOR_STATE) {
    case 1:  // no red
      if (rgb.r > 0) {
        if (rgb.g == 0) {
          rgb.g = rgb.r;
          rgb.r = 0;
        } else if (rgb.b == 0) {
          rgb.b = rgb.r;
          rgb.r = 0;
        }
      }
      break;
    
    case 2:  // no green
      if (rgb.g > 0) {
        if (rgb.r == 0) {
          rgb.r = rgb.g;
          rgb.g = 0;
        } else if (rgb.b == 0) {
          rgb.b = rgb.g;
          rgb.g = 0;
        }
      }
      break;
    
    case 3:  // no blue
      if (rgb.b > 0) {
        if (rgb.r == 0) {
          rgb.r = rgb.b;
          rgb.b = 0;
        } else if (rgb.g == 0) {
          rgb.g = rgb.b;
          rgb.b = 0;
        }
      }
      break;
    
    case 4:  // all red
      if (rgb.r == 0) {
        if (rgb.g > rgb.b) {
          rgb.r = rgb.g;
          rgb.g = 0;
        } else {
          rgb.r = rgb.b;
          rgb.b = 0;
        }
      }
      break;
    
    case 5:  // all green
      if (rgb.g == 0) {
        if (rgb.r > rgb.b) {
          rgb.g = rgb.r;
          rgb.r = 0;
        } else {
          rgb.g = rgb.b;
          rgb.b = 0;
        }
      }
      break;
    
    case 6:  // all blue
      if (rgb.b == 0) {
        if (rgb.r > rgb.g) {
          rgb.b = rgb.r;
          rgb.r = 0;
        } else {
          rgb.b = rgb.g;
          rgb.g = 0;
        }
      }
      break;
    
    default:
      break;
  }   
}

//
// Finish Cycle
//
// Get ready for the next morph cycle by morphing to the max and pushing the frame buffer
//
void finishCycle(byte channel) {
  morph_frame(channel, 1.0);  // May work after all. ToDo: Test
  pushColorBuffer(channel);
  start_time[channel] = millis();  // reset the clock
}

//
// Update Morph
//
void update_morph() {
  // Fractional morph over the span of delay_time
  for (byte channel = 0; channel < NUM_CHANNELS; channel++) {
    last_time[channel] = millis();  // update clock
    float fract = (last_time[channel] - start_time[channel]) / (float)delay_time[channel];
    if (is_channel_active(channel) && fract <= 1.0) {
      morph_frame(channel, fract);
    }
  }
}

//
// Is Channel Active
//
boolean is_channel_active(int channel) {
  return (channel_intensity[channel] > 0);
}


//
// Bottom Control functions
//
void drawCheckbox(int x, int y, int size, color fill, boolean checked) {
  stroke(0);
  fill(fill);  
  rect(x,y,size,size);
  if (checked) {    
    line(x,y,x+size,y+size);
    line(x+size,y,x,y+size);
  }  
}

void drawBottomControls() {
  rectMode(CORNER);
  
  // draw a bottom white region
  fill(255,255,255);
  rect(0,SCREEN_SIZE, SCREEN_SIZE,40);
  
  // draw divider lines
  stroke(0);
  line(140,SCREEN_SIZE,140,SCREEN_SIZE+40);
  line(290,SCREEN_SIZE,290,SCREEN_SIZE+40);
  line(470,SCREEN_SIZE,470,SCREEN_SIZE+40);
  
  // draw checkboxes
  stroke(0);
  fill(255,255,255);
  
  // Checkbox is always unchecked; it is 3-state
  rect(20,SCREEN_SIZE+10,20,20);  // label checkbox
  
  rect(200,SCREEN_SIZE+4,15,15);  // plus brightness
  rect(200,SCREEN_SIZE+22,15,15);  // minus brightness
  
  rect(600,SCREEN_SIZE+4,15,15);  // plus brightness
  rect(600,SCREEN_SIZE+22,15,15);  // minus brightness
  
  drawCheckbox(340,SCREEN_SIZE+4,15, color(255,0,0), COLOR_STATE == 1);
  drawCheckbox(340,SCREEN_SIZE+22,15, color(0,255,0), COLOR_STATE == 4);
  drawCheckbox(360,SCREEN_SIZE+4,15, color(0,0,255), COLOR_STATE == 2);
  drawCheckbox(360,SCREEN_SIZE+22,15, color(255,0,0), COLOR_STATE == 5);
  drawCheckbox(380,SCREEN_SIZE+4,15, color(0,255,0), COLOR_STATE == 3);
  drawCheckbox(380,SCREEN_SIZE+22,15, color(0,0,255), COLOR_STATE == 6);
  
  drawCheckbox(400,SCREEN_SIZE+10,20, color(0,0,255), COLOR_STATE == 0);
  
  // draw text labels in 12-point Helvetica
  fill(0);
  textAlign(LEFT);
  
  textFont(font_square, 12);
  text("Toggle Labels", 50, SCREEN_SIZE+25);
  text("+", 190, SCREEN_SIZE+16);
  text("-", 190, SCREEN_SIZE+34);
  text("Brightness", 225, SCREEN_SIZE+25);
  textFont(font_square, 20);
  text(BRIGHTNESS, 150, SCREEN_SIZE+28);
  
  textFont(font_square, 12);
  text("+", 590, SCREEN_SIZE+16);
  text("-", 590, SCREEN_SIZE+34);
  text("Speed", 625, SCREEN_SIZE+25);
  textFont(font_square, 20);
  text(SLOWNESS, 550, SCREEN_SIZE+28);
  
  textFont(font_square, 12);
  text("None", 305, SCREEN_SIZE+16);
  text("All", 318, SCREEN_SIZE+34);
  text("Color", 430, SCREEN_SIZE+25);
  
  // scale font to size of squares
  textFont(font_square, 8);
  
}

void mouseClicked() {  
  //println("click! x:" + mouseX + " y:" + mouseY);
  if (mouseX > 20 && mouseX < 40 && mouseY > SCREEN_SIZE+10 && mouseY < SCREEN_SIZE+30) {
    // clicked draw labels button
    DRAW_LABELS = (DRAW_LABELS + 1) % 3;
   
  }  else if (mouseX > 200 && mouseX < 215 && mouseY > SCREEN_SIZE+4 && mouseY < SCREEN_SIZE+19) {
    // Bright up checkbox
    if (BRIGHTNESS <= 95) BRIGHTNESS += 1;
    
  } else if (mouseX > 200 && mouseX < 215 && mouseY > SCREEN_SIZE+22 && mouseY < SCREEN_SIZE+37) {
    // Bright down checkbox
    BRIGHTNESS -= 2;  
    if (BRIGHTNESS < 1) BRIGHTNESS = 1;
  
  }  else if (mouseX > 600 && mouseX < 615 && mouseY > SCREEN_SIZE+4 && mouseY < SCREEN_SIZE+19) {
    // Slowness up checkbox
    if (SLOWNESS <= 100) SLOWNESS += 1;
    
  } else if (mouseX > 600 && mouseX < 615 && mouseY > SCREEN_SIZE+22 && mouseY < SCREEN_SIZE+37) {
    // Slowness down checkbox
    SLOWNESS -= 1;  
    if (SLOWNESS < 1) SLOWNESS = 1;
  
  }  else if (mouseX > 400 && mouseX < 420 && mouseY > SCREEN_SIZE+10 && mouseY < SCREEN_SIZE+30) {
    // No color correction  
    COLOR_STATE = 0;
   
  }  else if (mouseX > 340 && mouseX < 355 && mouseY > SCREEN_SIZE+4 && mouseY < SCREEN_SIZE+19) {
    // None red  
    COLOR_STATE = 1;
   
  }  else if (mouseX > 340 && mouseX < 355 && mouseY > SCREEN_SIZE+22 && mouseY < SCREEN_SIZE+37) {
    // All red  
    COLOR_STATE = 4;
   
  }  else if (mouseX > 360 && mouseX < 375 && mouseY > SCREEN_SIZE+4 && mouseY < SCREEN_SIZE+19) {
    // None blue  
    COLOR_STATE = 2;
   
  }  else if (mouseX > 360 && mouseX < 375 && mouseY > SCREEN_SIZE+22 && mouseY < SCREEN_SIZE+37) {
    // All blue  
    COLOR_STATE = 5;
   
  }  else if (mouseX > 380 && mouseX < 395 && mouseY > SCREEN_SIZE+4 && mouseY < SCREEN_SIZE+19) {
    // None green  
    COLOR_STATE = 3;
   
  }  else if (mouseX > 380 && mouseX < 395 && mouseY > SCREEN_SIZE+22 && mouseY < SCREEN_SIZE+37) {
    // All green  
    COLOR_STATE = 6;
    
  }
}

//
//  Routines for the strip buffer
//
void sendDataToLights() {
  if (testObserver.hasStrips) {   
    registry.startPushing();
    registry.setExtraDelay(10);
    registry.setAutoThrottle(true);
    registry.setAntiLog(true);    
    
    int trunk = 0;  // current trunk
    int double_trunk = 0;  // current strip
    int led = 0;  // current led
    int pixel = 0;
    
    color c;
    
    List<Strip> strip_list = registry.getStrips();
    Strip[] strips = new Strip[DOUBLE_TRUNKS];
    for (Strip strip : strip_list) {
      if (trunk < DOUBLE_TRUNKS && trunk < strips.length) {
        strips[trunk] = strip;
        trunk++;
      }
    }
    for (trunk = 0; trunk < NUMBER_TRUNKS; trunk++) {
//    for (trunk = 0; trunk < NUMBER_TRUNKS; trunk++) {
      double_trunk = trunk * 2;
      
      for (int i = 0; i < TRUNK_LEDS; i++) {
        pixel = i + (trunk * TRUNK_LEDS);
        
        c = get_color(interp_buffer[pixel][R_], interp_buffer[pixel][G_], interp_buffer[pixel][B_]);
        
        led = forward_led_lookup[i];

        if (led >= TRUNK_LEDS) {
          strips[double_trunk + 1].setPixel(c, led % TRUNK_LEDS);
        } else {
          strips[double_trunk].setPixel(c, led % TRUNK_LEDS);
        }
        
        led = reverse_led_lookup[i];

        if (led >= TRUNK_LEDS) {
          strips[double_trunk + 1].setPixel(c, led % TRUNK_LEDS);
        } else {
          strips[double_trunk].setPixel(c, led % TRUNK_LEDS);
        }
      }
    }
  }
}

color get_color(short r, short g, short b) {
  int new_r = r << 16;
  int new_g = g << 8;
  return new_r | new_g | b;
}

private void prepareExitHandler () {

  Runtime.getRuntime().addShutdownHook(new Thread(new Runnable() {

    public void run () {

      System.out.println("Shutdown hook running");

      List<Strip> strips = registry.getStrips();
      for (Strip strip : strips) {
        for (int i = 0; i < strip.getLength(); i++)
          strip.setPixel(#000000, i);
      }
      for (int i=0; i<100000; i++)
        Thread.yield();
    }
  }
  ));
}

void print_memory_usage() {
  long maxMemory = Runtime.getRuntime().maxMemory();
  long allocatedMemory = Runtime.getRuntime().totalMemory();
  long freeMemory = Runtime.getRuntime().freeMemory();
  int inUseMb = int(allocatedMemory / 1000000);
  
  if (inUseMb > 80) {
    println("Memory in use: " + inUseMb + "Mb");
  }  
}

short interp(short a, short b, float fract) {
  if (a == b) return a;
  if (fract <= 0) return a;
  if (fract >= 1) return b;
  return (short)(a + fract * (b - a));
}

short interp_wrap(short a, short b, float fract) {
  if (a == b) return a;
  if (fract <= 0) return a;
  if (fract >= 1) return b;
  
  float distCCW, distCW, answer;

  if (a >= b) {
    distCW = 256 + b - a;
    distCCW = a - b;
  } else {
    distCW = b - a;
    distCCW = 256 + a - b;
  }
  if (distCW <= distCCW) {
    answer = a + (distCW * fract);
  } else {
    answer = a - (distCCW * fract);
    if (answer < 0) {
      answer += 256;
    }
  }
  return (short)answer;
}

//
//  fill paired lookup array - calculate the 2nd paired led for all leds
//
//  uses nasty globals of pixel_counter and led_counter
//
void fill_paired_lookup_array() {
   map_one_tree();  // Map just the first tree's forward direction
   map_reverse_one_tree();  // Use a lookup table to map the reverse direction
   duplicate_trees();  // Copy the first tree on to the others
}

//
// duplicate trees - copy the first tree on to the other trees
//
void duplicate_trees() {
  for (int trunk = 1; trunk < NUMBER_TRUNKS; trunk++) {
    for (int pixel = 0; pixel < TRUNK_LEDS; pixel++) {
      forward_led_lookup[pixel + (TRUNK_LEDS * trunk)] = forward_led_lookup[pixel] + (FULL_TRUNK_LEDS * trunk);
      reverse_led_lookup[pixel + (TRUNK_LEDS * trunk)] = reverse_led_lookup[pixel] + (FULL_TRUNK_LEDS * trunk);
    }
  }
}

//
// map one tree
//
void map_one_tree() {
  map_forward_pixel_line(0);
  map_branch(1);
  map_reverse_pixel_line(0);
}

//
// map branch recursively
//  
void map_branch(int gen) {
   for (int branch = 1; branch <= NUMBER_BRANCHES; branch++) {
      if (gen > MAX_GENERATIONS) {
        return;  // ends the recursion
      }
      map_forward_pixel_line(gen);
      map_branch(gen + 1); //recursion here
      map_reverse_pixel_line(gen);
   }
}

void map_forward_pixel_line(int generation) {
  for (int pixel = 0; pixel < NUM_PIXELS_GEN[generation]; pixel++) {
    forward_led_lookup[forward_led_counter] = pixel_counter;
    pixel_counter++;
    forward_led_counter++;
  }
}

void map_reverse_pixel_line(int generation) {
  // Not mapping the reverse LEDs by hand. Instead, using a look-up table
  pixel_counter += NUM_PIXELS_GEN[generation];
}

void map_reverse_one_tree() {
  for (int pixel = 0; pixel < TRUNK_LEDS; pixel++) {
    reverse_led_lookup[pixel] = get_reverse_led(forward_led_lookup[pixel]);
  }
}

int get_reverse_led(int forward_led) {
  // Slow iteration over a lookup table, but I only need to do it once on setup
  for (int column = 0; column < reverse_lookup_table.length; column++) {
    if (forward_led >= reverse_lookup_table[column][0] && forward_led <= reverse_lookup_table[column][1]) {
      return reverse_lookup_table[column][2] - (forward_led - reverse_lookup_table[column][0]);
    }
  }
  println("Could not find reverse led for " + forward_led);
  return 0;
}
