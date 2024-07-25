/**************************************************
 * TPI programmer for ATtiny4/5/9/10/20/40
 *
 * Make the connections as shown below.
 *
 * To use:
 ***** Buad rate must be set to 9600 ****
 *
 *  - Upload to arduino and power off
 *  - Connect ATtiny10 as shown
 *  - Power on and open the serial monitor
 *  - If things are working so far you should
 *    see "NVM enabled" and "ATtiny10/20/40 connected".
 *  - Input one-letter commands via serial monitor:
 *
 *    D = dump memory. Displays all current memory
 *        on the chip
 *
 *    E = erase chip. Erases all program memory
 *        automatically done at time of programming
 *
 *    P = write program. After sending this, paste
 *        the program from the hex file into the
 *        serial monitor.
 *
 *    S = set fuse. follow the instructions to set
 *        one of the three fuses.
 *
 *    C = clear fuse. follow the instructions to clear
 *        one of the three fuses.
 *
 *    H = Toggle High Voltage Programming
 *
 *    T = Toggle +12v enabled by High, or Low
 *
 *    R/r = Quick reset
 *
 *  - Finally, power off the arduino and remove the
 *    Attiny10/20/40
 *
 *
 * Arduino                 ATtiny10               *
 * ----------+          +----------------         *
 * (SS#)  10 |--[R]-----| 6 (RESET#/PB3)          *
 *           |          |                         *
 * (MOSI) 11 |--[R]--+--| 1 (TPIDATA/PB0)         *
 *           |       |  |                         *
 * (MISO) 12 |--[R]--+  |                         *
 *           |          |                         *
 * (SCK)  13 |--[R]-----| 3 (TPICLK/PB1)          *
 * ----------+          +----------------         *
 *                                                *
 * ----------+          +----------------         *
 * (HVP)   9 |---       | 6 (RESET#/PB3)          *
 *           |          |                         *
 *                                                *
 *  -[R]-  =  a 220 - 1K Ohm resistor             *
 *                                                *
 *  this picture : 2011/12/08 by pcm1723          *
 *  modified :2015/02/27 by KD                    *
 *                                                *
 * thanks to pcm1723 for tpitest.pde upon which   *
 * this is based                                  *
 **************************************************
 Updates:
   Jan 23, 2017: Ksdsksd@gmail.com
                * Thanks to InoueTaichi Fixed incorrect #define Tiny40

   Mar 05, 2015: Ksdsksd@gamil.com
                * Added notifications to setting and clearing the system flags.

   Feb 23, 2015: Ksdsksd@gamil.com
                * Changed the programmer Diagram, This is the config I use, and get a sucessful programming of a tiny10 at 9600 baud.

   Mar 22, 2014: Ksdsksd@gmail.com
                * Added the quick reset to high before resetting the device.
                * Added code to stop the SPI and float the pins for testing the device while connected.

   Mar 20, 2014: Ksdsksd@gmail.com
                * Added a quick reset by sending 'r' or 'R' via the serial monitor.
                * Added a High voltage programming option from pin 9, toggled by 'H'
                * Added a High/low option for providing 12v to the reset pin, toggled by 'T'

   Mar 17, 2014: Ksdsksd@gmail.com
                * Had some trouble with the nibbles being swapped when programming on the 10 & 20,
                  added b1,b2 to hold the serial data before calling byteval()
                * Added Nat Blundell's patch to the code

   Apr 10, 2013: Ksdsksd@gmail.com
                * Applied Fix for setting and clearing flags

   Feb 7,  2013: Ksdsksd@gmail.com
                * Fixed programming timer, had intitial start at zero instead of current time.

   Dec 11, 2012: Ksdsksd@gmail.com
                * Added detect and programming for 4/5/9

   Dec 5-6, 2012: Ksdsksd@gmail.com
                * Incorperated read, and verify into program. Now have no program size limitation by using 328p.
                * Changed the outHex routines consolidated them into 1, number to be printed, and number of nibbles
                * Added a type check to distinguish between Tiny10/20/40
                * Added an auto word size check to ensure that there is the proper amount of words written for a 10/20/40
                * Removed Read program, Verify, and Finish from options
                * Changed baud rate to 19200 for delay from data written to the chip, to prevent serial buffer overrun.

   Oct 5, 2012: Ksdsksd@gmail.com
                *** Noticed that when programming, the verification fails
                    at times by last 1-2 bytes programmed, and the Tiny would act erratic.
                    Quick fix was adding 3 NOP's to the end the Tiny's code, and ignoring the errors, the Tiny then performed as expected.

   Oct 4, 2012: Ksdsksd@gmail.com
                * Moved all Serial printed strings to program space
                * Added code to detect Tiny20
*/

#include <SPI.h>
#include "pins_arduino.h"

// define the instruction set bytes
#define SLD    0x20
#define SLDp   0x24
#define SST    0x60
#define SSTp   0x64
#define SSTPRH 0x69
#define SSTPRL 0x68
// see functions below ////////////////////////////////
// SIN  0b0aa1aaaa replace a with 6 address bits
// SOUT 0b1aa1aaaa replace a with 6 address bits
// SLDCS  0b1000aaaa replace a with address bits
// SSTCS  0b1100aaaa replace a with address bits
///////////////////////////////////////////////////////
#define SKEY   0xE0
#define NVM_PROGRAM_ENABLE 0x1289AB45CDD888FFULL // the ULL means unsigned long long

#define NVMCMD 0x33
#define NVMCSR 0x32
#define NVM_NOP 0x00
#define NVM_CHIP_ERASE 0x10
#define NVM_SECTION_ERASE 0x14
#define NVM_WORD_WRITE 0x1D

#define HVReset 9

#define Tiny4_5 10
#define Tiny9 1
#define Tiny10 1
#define Tiny20 2
#define Tiny40 4

#define TimeOut 1
#define HexError 2
#define TooLarge 3
// represents the current pointer register value
unsigned short adrs = 0x0000;

// used for storing a program file
uint8_t data[16]; // program data
unsigned int progSize = 0; // program size in bytes

// used for various purposes
long startTime;
int timeout;
uint8_t b, b1, b2, b3;
boolean idChecked;
boolean correct;
char type; // type of chip connected 1 = Tiny10, 2 = Tiny20
char HVP = 0;
char HVON = 0;

// added by johanv: hardcoded program data
#define PROGRAM_BUTTON_PIN 2 // wire a button from this pin to GND
#define SUCCESS_LED_PIN 7 // wire a green LED from this pin to GND
#define FAILURE_LED_PIN 8 // wire a red LED from this pin to GND
const uint8_t hardcodedProgramData[] PROGMEM = {
  0xE0,   0xE0,   0xEE,   0xBF,   0xEF,   0xE5,   0xED,   0xBF,   0xE0,   0xE0,   0xF8,   0xED,   0xFC,   0xBF,   0xE6,   0xBF, 
  0x00,   0x00,   0x87,   0xE0,   0x33,   0x27,   0x8F,   0xD1,   0x99,   0x27,   0x26,   0xE0,   0x00,   0xE0,   0xE3,   0xE1, 
  0xE2,   0x0F,   0xF0,   0xE0,   0x09,   0x94,   0x14,   0xC0,   0x9C,   0xC0,   0x2C,   0xC0,   0x40,   0xC0,   0x6E,   0xC0, 
  0x8F,   0xC0,   0x1E,   0xC0,   0x44,   0xC0,   0x52,   0xC0,   0x6D,   0xC0,   0x6E,   0xC0,   0x9C,   0xC0,   0x14,   0xC1, 
  0xB4,   0xC0,   0xCA,   0xC0,   0xCC,   0xC0,   0x7C,   0xC0,   0x3F,   0xC0,   0xDA,   0xC0,   0x1F,   0xC0,   0x24,   0xC0, 
  0xE0,   0x2F,   0x81,   0xD1,   0xBB,   0x27,   0x32,   0xFD,   0x0A,   0x95,   0x00,   0x50,   0x09,   0xF0,   0x31,   0xFD, 
  0x03,   0x95,   0xE0,   0x2F,   0xE6,   0x50,   0x09,   0xF4,   0x0A,   0x95,   0x30,   0xFD,   0x26,   0xE0,   0x06,   0xC1, 
  0x42,   0xE2,   0x5B,   0xD1,   0x80,   0x62,   0xB3,   0x95,   0xB5,   0xFF,   0x00,   0xC1,   0x20,   0x2F,   0x01,   0xE0, 
  0x5A,   0xD1,   0xFC,   0xC0,   0x96,   0xD1,   0x9F,   0x2F,   0x23,   0xE1,   0xF8,   0xC0,   0x90,   0x50,   0x19,   0xF4, 
  0x60,   0x61,   0x11,   0xE4,   0x24,   0xE1,   0xF2,   0xC0,   0x1A,   0x95,   0x11,   0xF0,   0x30,   0xFF,   0xEE,   0xC0, 
  0x16,   0x95,   0x16,   0x95,   0xBB,   0x27,   0x26,   0xE0,   0x0C,   0xE0,   0xA2,   0xE0,   0xE7,   0xC0,   0x81,   0xD1, 
  0xAF,   0x2F,   0x11,   0xE0,   0xB1,   0xE0,   0x99,   0x27,   0x2E,   0xE0,   0x07,   0xE0,   0xDF,   0xC0,   0x8E,   0xD1, 
  0x99,   0x27,   0x2E,   0xE0,   0x01,   0xE1,   0xDA,   0xC0,   0x99,   0x27,   0x2E,   0xE0,   0x07,   0xE0,   0x33,   0xD1, 
  0xBA,   0x95,   0x19,   0xF4,   0xA0,   0xA9,   0xB1,   0x2F,   0x28,   0xE0,   0xD0,   0xC0,   0x30,   0x50,   0x61,   0xF0, 
  0x7D,   0xD1,   0x29,   0xD1,   0xC3,   0x23,   0x49,   0xF0,   0xBA,   0x95,   0x31,   0xF4,   0xA0,   0xA9,   0x99,   0x27, 
  0x2E,   0xE0,   0x07,   0xE0,   0x55,   0xD1,   0xB1,   0x2F,   0xC1,   0xC0,   0x5B,   0xD1,   0xBA,   0x95,   0xE9,   0xF7, 
  0x16,   0x95,   0xBB,   0x27,   0x26,   0xE0,   0x0C,   0xE0,   0xA3,   0xE0,   0xB8,   0xC0,   0xBB,   0x27,   0x10,   0xE0, 
  0x29,   0xE0,   0xB4,   0xC0,   0x2A,   0xE0,   0x62,   0xD1,   0xB3,   0x95,   0x71,   0xF0,   0x30,   0x50,   0x59,   0xF0, 
  0xEC,   0x2F,   0xE3,   0x23,   0x29,   0xF0,   0x3C,   0xD1,   0x06,   0xD1,   0x20,   0xE1,   0x09,   0xE0,   0xA6,   0xC0, 
  0x10,   0x50,   0x09,   0xF0,   0x1A,   0x95,   0xA2,   0xC0,   0x26,   0xE0,   0x0C,   0xE0,   0xA4,   0xE0,   0x9E,   0xC0, 
  0xB3,   0x95,   0xD1,   0xF3,   0xE8,   0x2F,   0xE7,   0x70,   0xE0,   0x50,   0x71,   0xF5,   0x20,   0x2F,   0x96,   0xC0, 
  0x32,   0xFD,   0x26,   0xE0,   0x00,   0xE0,   0xBB,   0x27,   0x2C,   0xD1,   0xE3,   0x95,   0x31,   0xFD,   0xFB,   0xD0, 
  0x8D,   0xC0,   0x41,   0xE1,   0x50,   0xE1,   0xE2,   0xD0,   0x80,   0x61,   0x99,   0x27,   0xA0,   0xE7,   0xC1,   0xE0, 
  0xBD,   0xE0,   0x10,   0xE0,   0x2B,   0xE0,   0x30,   0xFD,   0x18,   0xC0,   0xE9,   0x2F,   0xEB,   0x1B,   0xA1,   0xF4, 
  0x99,   0x27,   0xC0,   0xFD,   0xA6,   0x95,   0xC0,   0xFF,   0xAA,   0x0F,   0xE1,   0xD0,   0xA4,   0xFD,   0x40,   0x61, 
  0xA3,   0xFD,   0x51,   0x60,   0xA2,   0xFD,   0x70,   0x61,   0x50,   0xFD,   0x70,   0xC0,   0xC0,   0xFF,   0x02,   0xC0, 
  0x74,   0xFD,   0xC0,   0xE0,   0x44,   0xFD,   0xC1,   0xE0,   0x69,   0xC0,   0x2D,   0xE0,   0x40,   0xFD,   0x04,   0xC0, 
  0x44,   0xFF,   0x02,   0xC0,   0x4F,   0x70,   0x40,   0x64,   0x64,   0xFD,   0x04,   0xC0,   0x50,   0xFF,   0x02,   0xC0, 
  0x50,   0x7F,   0x54,   0x60,   0x70,   0xFD,   0x04,   0xC0,   0x74,   0xFF,   0x02,   0xC0,   0x7F,   0x70,   0x70,   0x64, 
  0x99,   0x27,   0x2E,   0xE0,   0x0F,   0xE0,   0x52,   0xC0,   0x95,   0xFD,   0x20,   0x2F,   0x4F,   0xC0,   0x46,   0xFF, 
  0x02,   0xC0,   0x40,   0x70,   0x44,   0x60,   0x52,   0xFF,   0x03,   0xC0,   0x50,   0x7F,   0x6F,   0x70,   0x60,   0x64, 
  0x76,   0xFF,   0x02,   0xC0,   0x70,   0x70,   0x74,   0x60,   0x99,   0x27,   0x2E,   0xE0,   0x02,   0xE1,   0x3E,   0xC0, 
  0x4B,   0x7F,   0x6F,   0x7B,   0x7B,   0x7F,   0xAA,   0x27,   0x44,   0xFD,   0xA4,   0x60,   0x50,   0xFD,   0xA2,   0x60, 
  0x74,   0xFD,   0xA1,   0x60,   0xA0,   0xFF,   0xA6,   0x95,   0xA0,   0xFF,   0xA6,   0x95,   0xA0,   0x50,   0x29,   0xF4, 
  0xBB,   0x27,   0x26,   0xE0,   0x0C,   0xE0,   0xA1,   0xE0,   0x29,   0xC0,   0x88,   0xD0,   0x10,   0xFF,   0x04,   0xC0, 
  0x40,   0x61,   0xA2,   0x95,   0xC1,   0xE0,   0x06,   0xC0,   0xC0,   0xE0,   0x70,   0x61,   0xA2,   0xFF,   0xAA,   0x0F, 
  0xA2,   0xFF,   0xAA,   0x0F,   0x99,   0x27,   0xAC,   0xD0,   0x2B,   0xE0,   0xE1,   0x2F,   0xE3,   0x50,   0x08,   0xF4, 
  0xBA,   0x95,   0xE1,   0x2F,   0xE9,   0x50,   0x08,   0xF4,   0xBA,   0x95,   0xE2,   0x50,   0x09,   0xF4,   0xBA,   0x95, 
  0xE3,   0x50,   0x61,   0xF4,   0xBA,   0x95,   0x0A,   0xC0,   0xE1,   0x2F,   0x75,   0xD0,   0x3E,   0x7F,   0x30,   0x50, 
  0x29,   0xF0,   0xBB,   0x27,   0x26,   0xE0,   0x0A,   0x2F,   0x32,   0xFD,   0x00,   0xE0,   0x38,   0x2F,   0x88,   0x7F, 
  0xD4,   0xE0,   0xD1,   0xB9,   0xE0,   0xE0,   0xE2,   0xB9,   0x48,   0xD0,   0x03,   0x9B,   0x8D,   0x2B,   0xD6,   0x95, 
  0xD0,   0x50,   0xB9,   0xF7,   0x30,   0x95,   0x38,   0x23,   0x37,   0x70,   0xE4,   0x2F,   0xE2,   0x95,   0xFC,   0xE0, 
  0xD4,   0xE0,   0x28,   0xD0,   0xE4,   0x2F,   0xFA,   0xE0,   0xD2,   0xE0,   0x24,   0xD0,   0xE5,   0x2F,   0xE2,   0x95, 
  0xF9,   0xE0,   0xD1,   0xE0,   0x1F,   0xD0,   0xE5,   0x2F,   0xF6,   0xE0,   0xD2,   0xE0,   0x1B,   0xD0,   0xE6,   0x2F, 
  0xE2,   0x95,   0xF6,   0xE0,   0xD4,   0xE0,   0x16,   0xD0,   0xE6,   0x2F,   0xF5,   0xE0,   0xD4,   0xE0,   0x12,   0xD0, 
  0xE7,   0x2F,   0xE2,   0x95,   0xF5,   0xE0,   0xD1,   0xE0,   0x0D,   0xD0,   0xE7,   0x2F,   0xF3,   0xE0,   0xD1,   0xE0, 
  0x09,   0xD0,   0xE8,   0x2F,   0xE2,   0x95,   0xF3,   0xE0,   0xD2,   0xE0,   0x04,   0xD0,   0xE0,   0xE0,   0xE1,   0xB9, 
  0x93,   0x95,   0x95,   0xCE,   0xF1,   0xB9,   0xF0,   0xE0,   0xF2,   0xB9,   0xE0,   0xFD,   0x05,   0xC0,   0xE1,   0xFD, 
  0x06,   0xC0,   0xE2,   0xFD,   0x92,   0xFD,   0x01,   0xC0,   0xD2,   0xB9,   0x09,   0xD0,   0x08,   0x95,   0x07,   0xD0, 
  0xD2,   0xB9,   0xE0,   0xE4,   0xF0,   0xE0,   0x05,   0xD0,   0x08,   0x95,   0xFB,   0xE0,   0x01,   0xC0,   0xF8,   0xE0, 
  0xEF,   0xEF,   0xE1,   0x50,   0xF0,   0x40,   0xE9,   0xF7,   0x08,   0x95,   0x54,   0x2F,   0x64,   0x2F,   0x75,   0x2F, 
  0x72,   0x95,   0x8F,   0x70,   0x08,   0x95,   0x44,   0x27,   0xF8,   0xDF,   0x08,   0x95,   0x40,   0xFB,   0x54,   0xF9, 
  0x62,   0x95,   0x70,   0xFB,   0x84,   0xF9,   0x42,   0x95,   0x50,   0xFB,   0x64,   0xF9,   0x72,   0x95,   0x4F,   0x70, 
  0x50,   0x7F,   0x7F,   0x70,   0x08,   0x95,   0xEF,   0xDF,   0xEA,   0x50,   0xA0,   0xF4,   0xE6,   0x5F,   0xE0,   0xFD, 
  0x60,   0x61,   0xE2,   0x50,   0xE0,   0xF0,   0x40,   0x61,   0x80,   0x61,   0xE2,   0x50,   0xC0,   0xF0,   0x50,   0x61, 
  0x70,   0x61,   0xE2,   0x50,   0xA0,   0xF0,   0x41,   0x60,   0x71,   0x60,   0xE2,   0x50,   0x80,   0xF0,   0x51,   0x60, 
  0x61,   0x60,   0x0D,   0xC0,   0xEF,   0x50,   0x10,   0xF0,   0x60,   0x61,   0xEF,   0xEF,   0xE0,   0x5F,   0xE0,   0xFD, 
  0x51,   0x60,   0xE1,   0xFD,   0x41,   0x60,   0xE2,   0xFD,   0x61,   0x60,   0xE3,   0xFD,   0x71,   0x60,   0x08,   0x95, 
  0x17,   0xFF,   0x13,   0x95,   0x08,   0x95,   0x88,   0x60,   0x93,   0x95,   0x09,   0xF4,   0x93,   0x95,   0x9A,   0x95, 
  0x90,   0xA9,   0x83,   0xFF,   0xF8,   0xCF,   0xE0,   0xA1,   0xFE,   0x2F,   0xEE,   0x0F,   0xEE,   0x0F,   0xFE,   0x27, 
  0xEE,   0x0F,   0xFE,   0x27,   0xEE,   0x0F,   0xFE,   0x27,   0xF0,   0x95,   0xE0,   0xA1,   0xFF,   0x1F,   0xEE,   0x1F, 
  0xE0,   0xA9,   0xFE,   0x2F,   0xE6,   0x50,   0xF0,   0xF7,   0xEA,   0x5F,   0x08,   0x95,   0xAC,   0xDF,   0xE9,   0xDF, 
  0xE2,   0x50,   0x28,   0xF0,   0xE2,   0x50,   0x30,   0xF0,   0x40,   0x61,   0xC4,   0xE0,   0x08,   0x95,   0x70,   0x61, 
  0xC2,   0xE0,   0x08,   0x95,   0x80,   0x61,   0xC1,   0xE0,   0x08,   0x95, 
};
const int hardcodedProgramSize = sizeof(hardcodedProgramData);


void setup()
{
  // set up serial
  Serial.begin(9600); // you cant increase this, it'll overrun the buffer
  Serial.println(F("setup")); // added by johanv
  // set up SPI
  /*  SPI.begin();
    SPI.setBitOrder(LSBFIRST);
    SPI.setDataMode(SPI_MODE0);
    SPI.setClockDivider(SPI_CLOCK_DIV32);

  */
  start_tpi();

  pinMode(HVReset, OUTPUT);
  // initialize memory pointer register
  setPointer(0x0000);

  timeout = 20000;
  idChecked = false;
  // added by johanv
  pinMode(SUCCESS_LED_PIN, OUTPUT);
  pinMode(FAILURE_LED_PIN, OUTPUT);
  pinMode(PROGRAM_BUTTON_PIN, INPUT_PULLUP);
} // end setup()

void handleButtonPress() //added by johanv
{
  //blink both LEDs twice to indicate that it is starting to flash the chip
  for (int i=0; i<2; i++) {
    digitalWrite(SUCCESS_LED_PIN, HIGH);
    digitalWrite(FAILURE_LED_PIN, HIGH);
    delay(50);

    digitalWrite(SUCCESS_LED_PIN, LOW);
    digitalWrite(FAILURE_LED_PIN, LOW);
    delay(50);
  }

  start_tpi();
  if (writeProgramHardcoded()) {
    setConfigNoSerial(true, 'r');
    // Indicate success with an LED
    digitalWrite(SUCCESS_LED_PIN, HIGH);
  } else {
    // Indicate failure with an LED
    digitalWrite(FAILURE_LED_PIN, HIGH);
  }
  finish();
}

void hvserial()
{
  if (HVP) {
    Serial.println(F("***High Voltage Programming Enabled***"));
  } else {
    Serial.println(F("High Voltage Programming Disabled"));
  }
  Serial.print(F("Pin 9 "));
  Serial.print(HVON ? F("HIGH") : F("LOW"));
  Serial.print(F(" supplies 12v"));
}

void hvReset(char highLow)
{
  if (HVP) {
    if (HVON) {           // if high enables 12v
      highLow = !highLow; // invert the typical reset
    }
    digitalWrite(HVReset, highLow);
  } else
    digitalWrite(SS, highLow);
}

void quickReset()
{
  digitalWrite(SS, HIGH);
  delay(1);
  digitalWrite(SS, LOW);
  delay(10);
  digitalWrite(SS, HIGH);
}

void start_tpi()
{
  SPI.begin();
  SPI.setBitOrder(LSBFIRST);
  SPI.setDataMode(SPI_MODE0);
  SPI.setClockDivider(SPI_CLOCK_DIV32);

  // enter TPI programming mode
  hvReset(LOW);
  // digitalWrite(SS, LOW); // assert RESET on tiny
  delay(1); // t_RST min = 400 ns @ Vcc = 5 V

  SPI.transfer(0xff); // activate TPI by emitting
  SPI.transfer(0xff); // 16 or more pulses on TPICLK
  SPI.transfer(0xff); // while holding TPIDATA to "1"

  writeCSS(0x02, 0x04); // TPIPCR, guard time = 8bits (default=128)

  send_skey(NVM_PROGRAM_ENABLE); // enable NVM interface
  // wait for NVM to be enabled
  while ((readCSS(0x00) & 0x02) < 1) {
    // wait
  }
  Serial.println(F("NVM enabled"));
}

void loop()
{
  if (!idChecked) {
    //    start_tpi();
    checkID();
    idChecked = true;
    finish();
    digitalWrite(SUCCESS_LED_PIN, HIGH);
    digitalWrite(FAILURE_LED_PIN, HIGH);
  }

  // when ready, send ready signal '.' and wait
  Serial.print(F("\n>"));
  bool buttonPressed = false;
  while (Serial.available() < 1) {
    delay(10);
    bool buttonPrev = buttonPressed;
    buttonPressed = !digitalRead(PROGRAM_BUTTON_PIN);
    if (buttonPressed && !buttonPrev) {
      handleButtonPress();
    }
  }
  start_tpi();

  // the first byte is a command
  //** 'P' = program the ATtiny using the read program
  //** 'D' = dump memory to serial monitor
  //** 'E' = erase chip. erases current program memory.(done automatically by 'P')
  //** 'S' = set fuse
  //** 'C' = clear fuse

  char comnd = Sread();

  switch (comnd) {
  case 'r':
  case 'R':
    quickReset();
    break;

  case 'D':
    dumpMemory();
    break;

  case 'H':
    HVP = !HVP;
    hvserial();
    break;

  case 'T':
    HVON = !HVON;
    hvserial();
    break;

  case 'P':
    // added by johanv: indicate success/failure with LEDs
    digitalWrite(SUCCESS_LED_PIN, LOW);
    digitalWrite(FAILURE_LED_PIN, LOW);
    if (writeProgram()) {
      digitalWrite(SUCCESS_LED_PIN, HIGH);
    } else {
      digitalWrite(FAILURE_LED_PIN, HIGH);
      startTime = millis();
      while (millis() - startTime < 8000)
        Serial.read(); // if exited due to error, disregard all other serial data
    }

    break;

  case 'E':
    eraseChip();
    break;

  case 'S':
    setConfig(true);
    break;

  case 'C':
    setConfig(false);
    break;

  default:
    Serial.println(F("Received unknown command"));
  }

  finish();
}

// added by johanv: function for programming using hardcoded data
boolean writeProgramHardcoded()
{
  unsigned int currentByte = 0;
  progSize = hardcodedProgramSize;
  boolean correct = true;
  unsigned long pgmStartTime = millis();
  eraseChip(); // erase chip
  char words = (type != Tiny4_5 ? type : 1);
  unsigned short tadrs;
  tadrs = adrs = 0x4000;

  for (int i = 0; i < progSize; i++) {
    data[currentByte] = pgm_read_byte(&(hardcodedProgramData[i]));
    currentByte++;
    if (currentByte == 2 * words) {
      currentByte = 0;
      setPointer(tadrs);
      writeIO(NVMCMD, NVM_WORD_WRITE);
      for (int j = 0; j < 2 * words; j += 2) {
        tpi_send_byte(SSTp);
        tpi_send_byte(data[j]);
        tpi_send_byte(SSTp);
        tpi_send_byte(data[j + 1]);
        SPI.transfer(0xff);
        SPI.transfer(0xff);
      }
      while ((readIO(NVMCSR) & (1 << 7)) != 0x00) { }
      writeIO(NVMCMD, NVM_NOP);
      SPI.transfer(0xff);
      SPI.transfer(0xff);

      setPointer(tadrs);
      for (int c = 0; c < 2 * words; c++) {
        tpi_send_byte(SLDp);
        b = tpi_receive_byte();
        if (b != data[c]) {
          correct = false;
          Serial.println(F("program error:"));
          Serial.print(F("byte "));
          outHex(adrs, 4);
          Serial.print(F(" expected "));
          outHex(data[c], 2);
          Serial.print(F(" read "));
          outHex(b, 2);
          Serial.println();
          return false;
        }
      }
      tadrs += 2 * words;
    }
  }
  Serial.print(F("Successfully wrote program: "));
  Serial.print(progSize, DEC);
  Serial.print(F(" bytes\n in "));
  Serial.print((millis() - pgmStartTime) / 1000.0, DEC);
  Serial.print(F(" Seconds"));
  return true;
}

// added by johanv: function for setting config directly instead of reading serial
void setConfigNoSerial(boolean val, char comnd)
{
  setPointer(0x3F40);
  tpi_send_byte(SLD);
  b = tpi_receive_byte();

  setPointer(0x3F40);
  writeIO(NVMCMD, (val ? NVM_WORD_WRITE : NVM_SECTION_ERASE));

  if (comnd == 'c') {
    tpi_send_byte(SSTp);
    tpi_send_byte(val ? (b & 0b11111011) : (b | 0x04));
    tpi_send_byte(SSTp);
    tpi_send_byte(0xFF);
  } else if (comnd == 'w') {
    tpi_send_byte(SSTp);
    tpi_send_byte(val ? (b & 0b11111101) : (b | 0x02));
    tpi_send_byte(SSTp);
    tpi_send_byte(0xFF);
  } else if (comnd == 'r') {
    tpi_send_byte(SSTp);
    tpi_send_byte(val ? (b & 0b11111110) : (b | 0x01));
    tpi_send_byte(SSTp);
    tpi_send_byte(0xFF);
  } else if (comnd == 'x') {
    return;
  } else {
    Serial.println(F("received unknown command. Cancelling"));
    return;
  }

  while ((readIO(NVMCSR) & (1 << 7)) != 0x00) { }
  writeIO(NVMCMD, NVM_NOP);
  SPI.transfer(0xff);
  SPI.transfer(0xff);

  if (comnd != 'x') {
    Serial.print(F("\n\nSuccessfully "));
    Serial.print(val ? F("Set ") : F("Cleared "));
    Serial.print(F("\""));
    if (comnd == 'w')
      Serial.print(F("Watchdog"));
    else if (comnd == 'c')
      Serial.print(F("Clock Output"));
    else if (comnd == 'r')
      Serial.print(F("Reset"));
    Serial.println(F("\" Flag\n"));
  }
}

void ERROR_pgmSize(void) { Serial.println(F("program size is 0??")); }

void ERROR_data(char i)
{
  Serial.println(F("couldn't receive data:"));
  switch (i) {
  case TimeOut:
    Serial.println(F("timed out"));
    break;
  case HexError:
    Serial.println(F("hex file format error"));
    break;
  case TooLarge:
    Serial.println(F("program is too large"));
    break;

  default:
    break;
  }
}

//  print the register, SRAM, config and signature memory
void dumpMemory()
{
  unsigned int len;
  uint8_t i;
  // initialize memory pointer register
  setPointer(0x0000);

  Serial.println(F("Current memory state:"));
  if (type != Tiny4_5)
    len = 0x400 * type; // the memory length for a 10/20/40 is 1024/2048/4096
  else
    len = 0x200; // tiny 4/5 has 512 bytes
  len += 0x4000;

  while (adrs < len) {
    // read the byte at the current pointer address
    // and increment address
    tpi_send_byte(SLDp);
    b = tpi_receive_byte(); // get data byte

    // read all the memory, but only print
    // the register, SRAM, config and signature memory
    if ((0x0000 <= adrs && adrs <= 0x005F) // register/SRAM
        | (0x3F00 <= adrs && adrs <= 0x3F01) // NVM lock bits
        | (0x3F40 <= adrs && adrs <= 0x3F41) // config
        | (0x3F80 <= adrs && adrs <= 0x3F81) // calibration
        | (0x3FC0 <= adrs && adrs <= 0x3FC3) // ID
        | (0x4000 <= adrs && adrs <= len - 1)) { // program
      // print +number along the top
      if ((0x00 == adrs) | (0x3f00 == adrs) // NVM lock bits
          | (0x3F40 == adrs) // config
          | (0x3F80 == adrs) // calibration
          | (0x3FC0 == adrs) // ID
          | (0x4000 == adrs)) {
        Serial.println();
        if(adrs == 0x0000){ Serial.print(F("registers, SRAM")); }
        if(adrs == 0x3F00){ Serial.print(F("NVM lock")); }
        if(adrs == 0x3F40){ Serial.print(F("configuration")); }
        if(adrs == 0x3F80){ Serial.print(F("calibration")); }
        if(adrs == 0x3FC0){ Serial.print(F("device ID")); }
        if(adrs == 0x4000){ Serial.print(F("program")); }
        Serial.println();
        for (i = 0; i < 5; i++)
          Serial.print(F(" "));
        for (i = 0; i < 16; i++) {
          Serial.print(F(" +"));
          Serial.print(i, HEX);
        }
      }
      // print number on the left
      if (0 == (0x000f & adrs)) {
        Serial.println();
        outHex(adrs, 4);
        Serial.print(F(": ")); // delimiter
      }
      outHex(b, 2);
      Serial.print(F(" "));
    }
    adrs++; // increment memory address
    if (adrs == 0x0060) {
      // skip reserved memory
      setPointer(0x3F00);
    }
  }
  Serial.println(F(" "));
} // end dumpMemory()

// receive and translate the contents of a hex file, Program and verify on the fly
boolean writeProgram()
{
  char datlength[] = "00";
  char addr[] = "0000";
  char something[] = "00";
  char chksm[] = "00";
  unsigned int currentByte = 0;
  progSize = 0;
  uint8_t linelength = 0;
  boolean fileEnd = false;
  unsigned short tadrs;
  tadrs = adrs = 0x4000;
  correct = true;
  unsigned long pgmStartTime = millis();
  eraseChip(); // erase chip
  char words = (type != Tiny4_5 ? type : 1);
  char b1, b2;
  // read in the data and
  while (!fileEnd) {
    startTime = millis();
    while (Serial.available() < 1) {
      if (millis() - startTime > timeout) {
        ERROR_data(TimeOut);
        return false;
      }
      if (pgmStartTime == 0)
        pgmStartTime = millis();
    }
    if (Sread() != ':') { // maybe it was a newline??
      if (Sread() != ':') {
        ERROR_data(HexError);
        return false;
      }
    }
    // read data length

    datlength[0] = Sread();
    datlength[1] = Sread();
    linelength = byteval(datlength[0], datlength[1]);

    // read address. if "0000" currentByte = 0
    addr[0] = Sread();
    addr[1] = Sread();
    addr[2] = Sread();
    addr[3] = Sread();
    if (linelength != 0x00 && addr[0] == '0' && addr[1] == '0' && addr[2] == '0' && addr[3] == '0')
      currentByte = 0;

    // read type thingy. "01" means end of file
    something[0] = Sread();
    something[1] = Sread();
    if (something[1] == '1') {
      fileEnd = true;
    }

    if (something[1] == '2') {
      for (int i = 0; i <= linelength; i++) {
        Sread();
        Sread();
      }

    } else {
      // read in the data
      for (int k = 0; k < linelength; k++) {
        while (Serial.available() < 1) {
          if (millis() - startTime > timeout) {
            ERROR_data(TimeOut);
            return false;
          }
        }
        b1 = Sread();
        b2 = Sread();
        data[currentByte] = byteval(b1, b2);
        currentByte++;
        progSize++;
        if (progSize > (type != Tiny4_5 ? type * 1024 : 512)) {
          ERROR_data(TooLarge);
          return 0;
        }

        if (fileEnd) // has the end of the file been reached?
          while (currentByte < 2 * words) { // append zeros to align the word count to program
            data[currentByte] = 0;
            currentByte++;
          }

        if (currentByte == 2 * words) { // is the word/Dword/Qword here?

          currentByte = 0; // yes, reset counter
          setPointer(tadrs); // point to the address to program
          writeIO(NVMCMD, NVM_WORD_WRITE);
          for (int i = 0; i < 2 * words; i += 2) { // loop for each word size depending on micro

            // now write a word to program memory
            tpi_send_byte(SSTp);
            tpi_send_byte(data[i]); // LSB first
            tpi_send_byte(SSTp);
            tpi_send_byte(data[i + 1]); // then MSB
            SPI.transfer(0xff); // send idle between words
            SPI.transfer(0xff); // send idle between words
          }
          while ((readIO(NVMCSR) & (1 << 7)) != 0x00) { } // wait for write to finish

          writeIO(NVMCMD, NVM_NOP);
          SPI.transfer(0xff);
          SPI.transfer(0xff);

          // verify written words
          setPointer(tadrs);
          for (int c = 0; c < 2 * words; c++) {
            tpi_send_byte(SLDp);
            b = tpi_receive_byte(); // get data byte

            if (b != data[c]) {
              correct = false;
              Serial.println(F("program error:"));
              Serial.print(F("byte "));
              outHex(adrs, 4);
              Serial.print(F(" expected "));
              outHex(data[c], 2);
              Serial.print(F(" read "));
              outHex(b, 2);
              Serial.println();

              if (!correct)
                return false;
            }
          }
          tadrs += 2 * words;
        }
      }

      // read in the checksum.
      startTime = millis();
      while (Serial.available() == 0) {
        if (millis() - startTime > timeout) {
          ERROR_data(TimeOut);
          return false;
        }
      }
      chksm[0] = Sread();
      chksm[1] = Sread();
    }
  }
  // the program was successfully written
  Serial.print(F("Successfully wrote program: "));
  Serial.print(progSize, DEC);
  Serial.print(F(" of "));
  if (type != Tiny4_5)
    Serial.print(1024 * type, DEC);
  else
    Serial.print(512, DEC);
  Serial.print(F(" bytes\n in "));
  Serial.print((millis() - pgmStartTime) / 1000.0, DEC);
  Serial.print(F(" Seconds"));
  //  digitalWrite(SS, HIGH); // release RESET

  return true;
}

void eraseChip()
{
  // initialize memory pointer register
  setPointer(0x4001); // need the +1 for chip erase

  // erase the chip
  writeIO(NVMCMD, NVM_CHIP_ERASE);
  tpi_send_byte(SSTp);
  tpi_send_byte(0xAA);
  tpi_send_byte(SSTp);
  tpi_send_byte(0xAA);
  tpi_send_byte(SSTp);
  tpi_send_byte(0xAA);
  tpi_send_byte(SSTp);
  tpi_send_byte(0xAA);
  while ((readIO(NVMCSR) & (1 << 7)) != 0x00) {
    // wait for erasing to finish
  }
  Serial.println(F("chip erased"));
}

void setConfig(boolean val)
{
  // get current config byte
  setPointer(0x3F40);
  tpi_send_byte(SLD);
  b = tpi_receive_byte();

  Serial.println(F("input one of these letters"));
  Serial.println(F("c = system clock output"));
  Serial.println(F("w = watchdog timer on"));
  Serial.println(F("r = disable reset"));
  Serial.println(F("x = cancel. don't change anything"));

  while (Serial.available() < 1) {
    // wait
  }
  char comnd = Serial.read();
  setPointer(0x3F40);
  writeIO(NVMCMD, (val ? NVM_WORD_WRITE : NVM_SECTION_ERASE));

  if (comnd == 'c') {
    tpi_send_byte(SSTp);
    if (val) {
      tpi_send_byte(b & 0b11111011);
    } else {
      tpi_send_byte(b | 0x04);
    }
    tpi_send_byte(SSTp);
    tpi_send_byte(0xFF);
  } else if (comnd == 'w') {
    tpi_send_byte(SSTp);
    if (val) {
      tpi_send_byte(b & 0b11111101);
    } else {
      tpi_send_byte(b | 0x02);
    }
    tpi_send_byte(SSTp);
    tpi_send_byte(0xFF);
  } else if (comnd == 'r') {
    tpi_send_byte(SSTp);
    if (val) {
      tpi_send_byte(b & 0b11111110);
    } else {
      tpi_send_byte(b | 0x01);
    }
    tpi_send_byte(SSTp);
    tpi_send_byte(0xFF);
  } else if (comnd == 'x') {
    // do nothing
  } else {
    Serial.println(F("received unknown command. Cancelling"));
  }
  while ((readIO(NVMCSR) & (1 << 7)) != 0x00) {
    // wait for write to finish
  }
  writeIO(NVMCMD, NVM_NOP);
  SPI.transfer(0xff);
  SPI.transfer(0xff);
  if (comnd != 'x') {

    Serial.print(F("\n\nSuccessfully "));
    if (val)
      Serial.print(F("Set "));
    else
      Serial.print(F("Cleared "));

    Serial.print(F("\""));
    if (comnd == 'w')
      Serial.print(F("Watchdog"));
    else if (comnd == 'c')
      Serial.print(F("Clock Output"));
    else if (comnd == 'r')
      Serial.print(F("Reset"));

    Serial.println(F("\" Flag\n"));
  }
}

void finish()
{
  writeCSS(0x00, 0x00);
  SPI.transfer(0xff);
  SPI.transfer(0xff);
  hvReset(HIGH);
  // digitalWrite(SS, HIGH); // release RESET
  delay(1); // t_RST min = 400 ns @ Vcc = 5 V
  SPI.end();
  DDRB &= 0b11000011; // tri-state spi so target can be tested
  PORTB &= 0b11000011;
}

void checkID()
{
  // check the device ID
  uint8_t id1, id2, id3;
  setPointer(0x3FC0);

  tpi_send_byte(SLDp);
  id1 = tpi_receive_byte();
  tpi_send_byte(SLDp);
  id2 = tpi_receive_byte();
  tpi_send_byte(SLDp);
  id3 = tpi_receive_byte();
  if (id1 == 0x1E && id2 == 0x8F && id3 == 0x0A) {
    Serial.print(F("ATtiny4"));
    type = Tiny4_5;
  } else if (id1 == 0x1E && id2 == 0x8F && id3 == 0x09) {
    Serial.print(F("ATtiny5"));
    type = Tiny4_5;
  } else if (id1 == 0x1E && id2 == 0x90 && id3 == 0x08) {
    Serial.print(F("ATtiny9"));
    type = Tiny9;
  } else if (id1 == 0x1E && id2 == 0x90 && id3 == 0x03) {
    Serial.print(F("ATtiny10"));
    type = Tiny10;
  } else if (id1 == 0x1E && id2 == 0x91 && id3 == 0x0f) {
    Serial.print(F("ATtiny20"));
    type = Tiny20;
  } else if (id1 == 0x1E && id2 == 0x92 && id3 == 0x0e) {
    Serial.print(F("ATtiny40"));
    type = Tiny40;
  } else {
    Serial.print(F("Unknown chip"));
  }
  Serial.println(F(" connected"));
}

/*
 * send a byte in one TPI frame (12 bits)
 * (1 start + 8 data + 1 parity + 2 stop)
 * using 2 SPI data bytes (2 x 8 = 16 clocks)
 * (with 4 extra idle bits)
 */
void tpi_send_byte(uint8_t data)
{
  // compute partiy bit
  uint8_t par = data;
  par ^= (par >> 4); // b[7:4] (+) b[3:0]
  par ^= (par >> 2); // b[3:2] (+) b[1:0]
  par ^= (par >> 1); // b[1] (+) b[0]

  // REMEMBER: this is in LSBfirst mode and idle is high
  // (2 idle) + (1 start bit) + (data[4:0])
  SPI.transfer(0x03 | (data << 3));
  // (data[7:5]) + (1 parity) + (2 stop bits) + (2 idle)
  SPI.transfer(0xf0 | (par << 3) | (data >> 5));
} // end tpi_send_byte()

/*
 * receive TPI 12-bit format byte data
 * via SPI 2 bytes (16 clocks) or 3 bytes (24 clocks)
 */
uint8_t tpi_receive_byte(void)
{
  // uint8_t b1, b2, b3;
  // keep transmitting high(idle) while waiting for a start bit
  do {
    b1 = SPI.transfer(0xff);
  } while (0xff == b1);
  // get (partial) data bits
  b2 = SPI.transfer(0xff);
  // if the first byte(b1) contains less than 4 data bits
  // we need to get a third byte to get the parity and stop bits
  if (0x0f == (0x0f & b1)) {
    b3 = SPI.transfer(0xff);
  }

  // now shift the bits into the right positions
  // b1 should hold only idle and start bits = 0b01111111
  while (0x7f != b1) { // data not aligned
    b2 <<= 1; // shift left data bits
    if (0x80 & b1) { // carry from 1st byte
      b2 |= 1; // set bit
    }
    b1 <<= 1;
    b1 |= 0x01; // fill with idle bit (1)
  }
  // now the data byte is stored in b2
  return (b2);
} // end tpi_receive_byte()

// send the 64 bit NVM key
void send_skey(uint64_t nvm_key)
{
  tpi_send_byte(SKEY);
  while (nvm_key) {
    tpi_send_byte(nvm_key & 0xFF);
    nvm_key >>= 8;
  }
} // end send_skey()

// sets the pointer address
void setPointer(unsigned short address)
{
  adrs = address;
  tpi_send_byte(SSTPRL);
  tpi_send_byte(address & 0xff);
  tpi_send_byte(SSTPRH);
  tpi_send_byte((address >> 8) & 0xff);
}

// writes using SOUT
void writeIO(uint8_t address, uint8_t value)
{
  //  SOUT 0b1aa1aaaa replace a with 6 address bits
  tpi_send_byte(0x90 | (address & 0x0F) | ((address & 0x30) << 1));
  tpi_send_byte(value);
}

// reads using SIN
uint8_t readIO(uint8_t address)
{
  //  SIN 0b0aa1aaaa replace a with 6 address bits
  tpi_send_byte(0x10 | (address & 0x0F) | ((address & 0x30) << 1));
  return tpi_receive_byte();
}

// writes to CSS
void writeCSS(uint8_t address, uint8_t value)
{
  tpi_send_byte(0xC0 | address);
  tpi_send_byte(value);
}

// reads from CSS
uint8_t readCSS(uint8_t address)
{
  tpi_send_byte(0x80 | address);
  return tpi_receive_byte();
}

// converts two chars to one byte
// c1 is MS, c2 is LS
uint8_t byteval(char c1, char c2)
{
  uint8_t by;
  if (c1 <= '9') {
    by = c1 - '0';
  } else {
    by = c1 - 'A' + 10;
  }
  by = by << 4;
  if (c2 <= '9') {
    by += c2 - '0';
  } else {
    by += c2 - 'A' + 10;
  }
  return by;
}

char Sread(void)
{
  while (Serial.available() < 1) { }
  return Serial.read();
}

void outHex(unsigned int n, char l)
{ // call with the number to be printed, and # of nibbles expected.
  for (char count = l - 1; count > 0; count--) { // quick and dirty to add zeros to the hex value
    if (((n >> (count * 4)) & 0x0f) == 0) // if MSB is 0
      Serial.print(F("0")); // prepend a 0
    else
      break; // exit the for loop
  }
  Serial.print(n, HEX);
}

// end of file
