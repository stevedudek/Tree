/*
  Tree Simulator and Lighter
  
  1. Simulator: draws squares on the monitor
  2. Lighter: sends data to the lights
  
  7/13/18
  
  API
  
  Python Showrunner sends: pixel, h, s, b
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
int SLOWNESS = 1;
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
color[][] curr_buffer = new color[NUM_CHANNELS][TOTAL_LEDS];
color[][] next_buffer = new color[NUM_CHANNELS][TOTAL_LEDS];
color[][] morph_buffer = new color[NUM_CHANNELS][TOTAL_LEDS];  // blend of curr + next
color[] interp_buffer = new color[TOTAL_LEDS];  // combine two channels here

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



//
// setup
//
void setup() {
  size(SCREEN_SIZE, SCREEN_SIZE + 50); // 50 for controls
  fill(255,255,0);
  
  frameRate(20);
  
  registry = new DeviceRegistry();
  testObserver = new TestObserver();
  registry.addObserver(testObserver);
  prepareExitHandler();
  strips = registry.getStrips();
  
  colorMode(HSB, 255);  // HSB colors (not RGB)
  
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
    fill(interp_buffer[led]);
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
  color black = color(0,0,0); 
  for (int i = 0; i < TOTAL_LEDS; i++) {
    curr_buffer[c][i] = black;
    next_buffer[c][i] = black;
  }
}

void pushColorBuffer(byte c) {
  for (int i = 0; i < TOTAL_LEDS; i++) {
    curr_buffer[c][i] = next_buffer[c][i];
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
//     d. Otherwise, process 4 integers as (i, h,s,v)
//
//
void processCommand(String cmd) {
  if (cmd.length() < 2) { return; }  // Discard erroneous stub characters
  byte channel = (cmd.charAt(0) == '0') ? (byte)0 : (byte)1 ;  // First letter indicates Channel 0 or 1
  cmd = cmd.substring(1, cmd.length());  // Strip off first-letter Channel indicator
  
  if (cmd.charAt(0) == 'X') {  // Finish the cycle
    finishCycle(channel);
  } else if (cmd.charAt(0) == 'D') {  // Get the delay time
    delay_time[channel] = Integer.valueOf(cmd.substring(1, cmd.length())) / SLOWNESS;
  } else if (cmd.charAt(0) == 'I') {  // Get the intensity
    channel_intensity[channel] = Integer.valueOf(cmd.substring(1, cmd.length())).shortValue();
  } else {  
    processPixelCommand(channel, cmd);  // Pixel command
  }
}

// 4 comma-separated numbers for i, h, s, v
Pattern cmd_pattern = Pattern.compile("^\\s*(\\d+),(\\d+),(\\d+),(\\d+)\\s*$");

void processPixelCommand(byte channel, String cmd) {
  Matcher m = cmd_pattern.matcher(cmd);
  if (!m.find()) {
    //println(cmd);
    println("ignoring input for " + cmd);
    return;
  }
  int i = Integer.valueOf(m.group(1));
  int h = Integer.valueOf(m.group(2));
  int s = Integer.valueOf(m.group(3));
  int v = Integer.valueOf(m.group(4));
  
  if (i > TOTAL_LEDS) {
    println("LED index of %d is too large", i);
    return;
  }
  next_buffer[channel][i] = color( (short)h, (short)s, (short)v );  
//  println(String.format("setting channel %d pixel:%d to h:%d, s:%d, v:%d", channel, i, h, s, v));
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
  for (int i = 0; i < TOTAL_LEDS; i++) {
    interp_buffer[i] = adjColor(morph_buffer[channel][i]);
  }
}

//
// morphBetweenChannels - interpolate the morph_channel on to the simulator
//
void morphBetweenChannels(float fract) {
  for (int i = 0; i < TOTAL_LEDS; i++) {
    interp_buffer[i] = adjColor(interp_color(morph_buffer[1][i], morph_buffer[0][i], fract));
  }
}

//
//  Fractional morphing between current and next frame - sends data to lights
//
//  fract is an 0.0 - 1.0 fraction towards the next frame
//
void morph_frame(byte c, float fract) {
  for (int i = 0; i < TOTAL_LEDS; i++) {
    morph_buffer[c][i] = interp_color(curr_buffer[c][i], next_buffer[c][i], fract);
  }
}

// Adjust color for brightness and hue
color adjColor(color c) {
  return c;  // Remove after debugging
//  return adj_brightness(colorCorrect(c));
}

color adj_brightness(color c) {
  // Adjust only the 3rd brightness channel
  return color(hue(c), saturation(c), int(brightness(c) * BRIGHTNESS / 100) );
}

color colorCorrect(color c) {
  int new_hue;
  
  switch(COLOR_STATE) {
    case 1:  // no red
      new_hue = map_range(hue(c), 40, 200);
      break;
    
    case 2:  // no green
      new_hue = map_range(hue(c), 120, 45);
      break;
    
    case 3:  // no blue
      new_hue = map_range(hue(c), 200, 120);
      break;
    
    case 4:  // all red
      new_hue = map_range(hue(c), 200, 40);
      break;
    
    case 5:  // all green
      new_hue = map_range(hue(c), 40, 130);
      break;
    
    case 6:  // all blue
      new_hue = map_range(hue(c), 120, 200);
      break;
    
    default:  // all colors
      new_hue = int(hue(c));
      break;
  }
  return color(new_hue, saturation(c), brightness(c));
}

//
// map_range - map a hue (0-255) to a smaller range (start-end)
//
int map_range(float hue, int start, int end) {
  int range = (end > start) ? end - start : (end + 256 - start) % 256 ;
  return int(start + ((hue / 255.0) * range)) % 256;
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
  fill(0,0,255);
  rect(0,SCREEN_SIZE, SCREEN_SIZE,40);
  
  // draw divider lines
  stroke(0);
  line(140,SCREEN_SIZE,140,SCREEN_SIZE+40);
  line(290,SCREEN_SIZE,290,SCREEN_SIZE+40);
  line(470,SCREEN_SIZE,470,SCREEN_SIZE+40);
  
  // draw checkboxes
  stroke(0);
  fill(0,0,255);
  
  // Checkbox is always unchecked; it is 3-state
  rect(20,SCREEN_SIZE+10,20,20);  // label checkbox
  
  rect(200,SCREEN_SIZE+4,15,15);  // plus brightness
  rect(200,SCREEN_SIZE+22,15,15);  // minus brightness
  
  drawCheckbox(340,SCREEN_SIZE+4,15, color(255,255,255), COLOR_STATE == 1);
  drawCheckbox(340,SCREEN_SIZE+22,15, color(255,255,255), COLOR_STATE == 4);
  drawCheckbox(360,SCREEN_SIZE+4,15, color(87,255,255), COLOR_STATE == 2);
  drawCheckbox(360,SCREEN_SIZE+22,15, color(87,255,255), COLOR_STATE == 5);
  drawCheckbox(380,SCREEN_SIZE+4,15, color(175,255,255), COLOR_STATE == 3);
  drawCheckbox(380,SCREEN_SIZE+22,15, color(175,255,255), COLOR_STATE == 6);
  
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
    if (BRIGHTNESS <= 95) BRIGHTNESS += 5;
    
  } else if (mouseX > 200 && mouseX < 215 && mouseY > SCREEN_SIZE+22 && mouseY < SCREEN_SIZE+37) {
    // Bright down checkbox
    BRIGHTNESS -= 5;  
    if (BRIGHTNESS < 1) BRIGHTNESS = 1;
  
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
    registry.setExtraDelay(0);
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
      double_trunk = trunk * 2;
      
      for (int i = 0; i < TRUNK_LEDS; i++) {
        pixel = i + (trunk * TRUNK_LEDS);
        c = interp_buffer[pixel];
        
        // Testing
        if (brightness(c) > 0) {
          println(hue(c), saturation(c), brightness(c));
        }
        
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

color interp_color(color c1, color c2, float fract) {
  int h,s,b;
  if (c1 == c2) {
    return c1;
  } else if (fract <= 0) {
    return c1;
  } else if (fract >= 1) {
    return c2; 
  } else if (is_black(c1)) {
    h = int(hue(c2));
    s = interpolate(0, saturation(c2), fract);
    b = interpolate(0, brightness(c2), fract);
  } else if (is_black(c2)) {
    h = int(hue(c1));
    s = rev_interpolate(0, saturation(c1), fract);
    b = rev_interpolate(0, brightness(c1), fract);
//    return color(int(hue(c1)), int(saturation(c1) * (1.0 - fract)), int(brightness(c1) * (1.0 - fract)) );
//   return color(hue(c1), saturation(c1), brightness(c1) * (1.0 - fract));

 } else {
   // Try always Be Saturated (sat = 255)
   // ToDo: I don't think works as well as you think it does
//   println(hue(c1), saturation(c1), brightness(c1));
//   println(hue(c2), saturation(c2), brightness(c2));
//   println(interpolate_wrap(hue(c1), hue(c2), fract), 255, lerp(brightness(c1), brightness(c2), fract));
//   println();
    h = interpolate_wrap(hue(c1), hue(c2), fract);
    s = interpolate(saturation(c1), saturation(c2), fract);
    b = interpolate(brightness(c1), brightness(c2), fract);
                 
//    return color(interpolate_wrap(int(hue(c1)), int(hue(c2)), fract),
//                 int(lerp(saturation(c1), saturation(c2), fract)),  // 255 ?
//                 int(lerp(brightness(c1), brightness(c2), fract)) );
 }
 color new_color = color(h,s,b);
 println(h,hue(new_color), s, saturation(new_color), b, brightness(new_color));
 return color(h,s,b);
}

int interpolate(float a, float b, float fract) {
  return int(a + fract * (b - a));
}

int rev_interpolate(float a, float b, float fract) {
  return interpolate(a, b, 1 - fract);
}

int interpolate_wrap(float a, float b, float fract) {
  
  // Can I do this with bytes?
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
  return int(answer);
}

boolean is_black(color c) {
  return brightness(c) == 0;  // Try both
//  return (hue(c) == 0 && saturation(c) == 0 && brightness(c) == 0);
}

boolean is_same_color(color c1, color c2) {
  return hue(c1) == hue(c2) && saturation(c1) == saturation(c2) && brightness(c1) == brightness(c2);
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
