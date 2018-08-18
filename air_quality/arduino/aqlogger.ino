// Moteino-MEGA board
// Using PMS Library to communicate on pins 10 and 11
// See boards.txt, platform.txt and variants/MoteinoMEGA/pins_arduino.h
// in packages/Moteino/hardware/avr/1.4.0
#ifdef ARDUINO_AVR_ATmega1284
#include <SoftwareSerial.h>
#else
#error "Wrong board - Please select MoteinoMEGA"
#endif

#ifdef __AVR_ATmega1284P__
// Moteino MEGA
#else
// Moteino
#endif

#define HAVE_PMS

void printTime(unsigned long msecs) {
  char str[32] = "";
  unsigned long seconds = msecs / 1000;
  int days = seconds / 86400;
  seconds %= 86400;
  byte hours = seconds / 3600;
  seconds %= 3600;
  byte minutes = seconds / 60;
  seconds %= 60;
  snprintf(str, sizeof(str), "%02d:%02d:%02d", hours, minutes, seconds);
  Serial.print(str);
}


void openSerialMonitor() {
  // Open serial communications and wait for port to open:
  Serial.begin(115200);
  while (!Serial) {
    ; // Wait for serial port to connect. Needed for native USB port only
  }
  printTime(millis());
  Serial.println(" Serial monitor ready.");
}

#ifdef HAVE_PMS
#include <PMS.h>

// AQI calculations for particulates per EPA Publication No. EPA-454/B-16-002, May 2016
// "Technical Assistance Document for the Reporting of Daily Air Quality
// – the Air Quality Index (AQI)"
// Available from https://www3.epa.gov/airnow/aqi-technical-assistance-document-may2016.pdf

#define AQI_LEVELS 14
#define LAST_BP 12

struct Pollutant {
  float roundFactor;
  float breakpoints[AQI_LEVELS];
};

const struct Pollutant pm25 = { 10.0, {
    0.0,  12.0,  12.1,  35.4,  35.5,  55.4,
   55.5, 150.4, 150.5, 250.4, 250.5, 350.4,
  350.5, 500.4 } };

const struct Pollutant pm10 = { 1.0, {
    0,  54,  55, 154, 155, 254,
  255, 354, 355, 424, 425, 504,
  505, 604 } };

const int aqiBreakpoints[AQI_LEVELS] = {
    0,  50,  51, 100, 101, 150,
  151, 200, 201, 300, 301, 400,
  401, 500 };

int pollutantAqi(const struct Pollutant& p, float value) {
  float valRounded = round(value * p.roundFactor) / p.roundFactor;
  int i = 0;
  while (i < LAST_BP && valRounded > p.breakpoints[i+1]) {
    i += 2;
  }
  float polDiff = valRounded - p.breakpoints[i];
  float polRange = p.breakpoints[i+1] - p.breakpoints[i];
  float aqiRange = float(aqiBreakpoints[i+1] - aqiBreakpoints[i]);
  float bpLo = float(aqiBreakpoints[i]);
  float aqi = bpLo + (aqiRange * polDiff / polRange);
  return round(aqi);
}

int totalAqi(float pm25value, float pm10value) {
  int aqi25 = pollutantAqi(pm25, pm25value);
  int aqi10 = pollutantAqi(pm10, pm10value);
  return max(aqi25, aqi10);
}

// Class that manages PMSx003 sensors
class PmSensor {
public:
  static const int PMSENSOR_SLEEPING = 0;
  static const int PMSENSOR_WAKING = 1;

  Stream *serial_; // HardwareSerial or SoftwareSerial
  PMS *pms_;
  PMS::DATA data_;
  unsigned long interval;
  unsigned long nextWakeup;
  unsigned long nextRead;
  int state;

  PmSensor(unsigned long ival) {
    serial_ = NULL;
    pms_ = NULL;
    interval = ival;
    nextWakeup = 0;
    nextRead = 0;
    state = PMSENSOR_SLEEPING;
  }

  void setup(Stream* serial) {
    // And switch to passive mode.
    serial_ = serial;
    pms_ = new PMS(*serial_);
    pms_->passiveMode();
    nextWakeup = millis();
  }

  bool willSleep() {
    interval >= 3 * PMS::STEADY_RESPONSE_TIME;
  }

  void update() {
    unsigned long time = millis();

    if (state == PMSENSOR_SLEEPING) {
      if (time >= nextWakeup) {
        nextRead = time + PMS::STEADY_RESPONSE_TIME;

        printTime(time);
        Serial.print(" Waking up PMS. Waiting until ");
        printTime(nextRead);
        Serial.println(" for  readings...");

        if (willSleep()) {
          nextWakeup += interval;
          Serial.print("Next wake up at ");
          printTime(nextWakeup);
          Serial.println(".");
        }

        state = PMSENSOR_WAKING;
        digitalWrite(LED_BUILTIN, HIGH);
        pms_->wakeUp();
      }
      return;
    }

    if (state == PMSENSOR_WAKING) {
      if (time >= nextRead) {
        printTime(time);
        Serial.println(" Sending read request to PMS...");
        pms_->requestRead();

        printTime(millis());
        Serial.println(" Waiting max. 1 second for read...");
        if (pms_->readUntil(data_, PMS::SINGLE_RESPONSE_TIME)) { // 1000
          Serial.print("PM 1.0 (ug/m3): ");
          Serial.println(data_.PM_AE_UG_1_0);

          Serial.print("PM 2.5 (ug/m3): ");
          Serial.println(data_.PM_AE_UG_2_5);

          Serial.print("PM 10.0 (ug/m3): ");
          Serial.println(data_.PM_AE_UG_10_0);

          int aqi25 = pollutantAqi(pm25, float(data_.PM_AE_UG_2_5));
          Serial.print("AQI 2.5: ");
          Serial.println(aqi25);

          int aqi10 = pollutantAqi(pm10, float(data_.PM_AE_UG_10_0));
          Serial.print("AQI 10: ");
          Serial.println(aqi10);
        } else {
          Serial.println("No data.");
        }

        if (willSleep()) {
          printTime(millis());
          Serial.print(" Sleeping PMS until ");
          printTime(nextWakeup);
          Serial.println(".");

          state = PMSENSOR_SLEEPING;
          digitalWrite(LED_BUILTIN, LOW);
          pms_->sleep();
        } else {
          nextRead += interval;
          Serial.print("Next read at ");
          printTime(nextRead);
          Serial.println(".");
        }
      }
      return;
    }
  }
};

#endif

#ifdef HAVE_GPS
#include <Adafruit_GPS.h>

// Set GPSECHO to 'false' to turn off echoing the GPS data to the Serial console
// Set to 'true' if you want to debug and listen to the raw GPS sentences.
#define GPSECHO  true

// Needed for SIGNAL
static Adafruit_GPS* gpsInstance = NULL;

// Interrupt is called once a millisecond, looks for any new GPS data, and stores it
SIGNAL(TIMER0_COMPA_vect) {
  char c = gpsInstance ? gpsInstance->read() : 0;
  // if you want to debug, this is a good time to do it!

#ifdef UDR0
  if (GPSECHO) {
    if (c) {
      // writing direct to UDR0 is much much faster than Serial.print
      // but only one character can be written at a time.
      UDR0 = c;
    }
  }
#endif
}

class GpsSensor {
public:
  const int GPSSENSOR_INIT = 0;
  const int GPSSENSOR_READY = 1;
  const int GPSSENSOR_HASDATA = 2;

  Stream *serial_; // HardwareSerial or SoftwareSerial
  Adafruit_GPS *gps_;
  unsigned long interval;
  int state;
  unsigned long nextWakeup;
  boolean usingInterrupt;

  // If using hardware serial (e.g. Arduino Mega), comment out the
  // above SoftwareSerial line, and enable this line instead
  // (you can change the Serial number to match your wiring):
  GpsSensor(unsigned long ival) {
    serial_ = NULL;
    gps_ = NULL;
    interval = ival;
    usingInterrupt = false;
    nextWakeup = 0;
    state = GPSSENSOR_INIT;
  }

  void setup(Stream* serial) {
    serial_ = serial;
    gpsInstance =  new Adafruit_GPS(serial_);
    gps_ = gpsInstance;

    printTime(millis());
    Serial.println(" Adafruit GPS library basic test.");

    // 9600 NMEA is the default baud rate for Adafruit MTK GPS's- some use 4800
    gps_->begin(9600);

    // uncomment this line to turn on RMC (recommended minimum) and GGA (fix data) including altitude
    gps_->sendCommand(PMTK_SET_NMEA_OUTPUT_RMCGGA);

    // uncomment this line to turn on only the "minimum recommended" data
    // gps_->.sendCommand(PMTK_SET_NMEA_OUTPUT_RMCONLY);
    // For parsing data, we don't suggest using anything but either RMC only or RMC+GGA since
    // the parser doesn't care about other sentences at this time

    // Set the update rate
    gps_->sendCommand(PMTK_SET_NMEA_UPDATE_1HZ);   // 1 Hz update rate
    // For the parsing code to work nicely and have time to sort thru the data, and
    // print it out we don't suggest using anything higher than 1 Hz

    // Request updates on antenna status, comment out to keep quiet
    gps_->sendCommand(PGCMD_ANTENNA);

    // the nice thing about this code is you can have a timer0 interrupt go off
    // every 1 millisecond, and read data from the GPS for you. that makes the
    // loop code a heck of a lot easier!
    if (usingInterrupt) {
      useInterrupt(true);
    }

    nextWakeup = millis() + 1000;
  }

  void update() {
    unsigned long time = millis();
    if (time >= nextWakeup) {
      if (state == GPSSENSOR_INIT) {
        state = GPSSENSOR_READY;
        // Ask for firmware version
        serial_->println(PMTK_Q_RELEASE);
      }

      nextWakeup += interval;

      if (state == GPSSENSOR_READY) {
        // in case you are not using the interrupt above, you'll
        // need to 'hand query' the GPS, not suggested :(
        if (!usingInterrupt) {
          // read data from the GPS in the 'main loop'
          char c = gps_->read();
          // if you want to debug, this is a good time to do it!
          if (GPSECHO) {
            if (c) {
              Serial.print(c);
            }
          }
        }

        // if a sentence is received, we can check the checksum, parse it...
        if (gps_->newNMEAreceived()) {
          // a tricky thing here is if we print the NMEA sentence, or data
          // we end up not listening and catching other sentences!
          // so be very wary if using OUTPUT_ALLDATA and trytng to print out data
          //Serial.println(gps_->lastNMEA());   // this also sets the newNMEAreceived() flag to false

          if (gps_->parse(gps_->lastNMEA()))   // this also sets the newNMEAreceived() flag to false
            state = GPSSENSOR_HASDATA;
        }

        printTime(time);
        if (state == GPSSENSOR_HASDATA) {
          char tstr[32] = "";
          snprintf(tstr, sizeof(tstr), "%02d:%02d:%02d", gps_->hour, gps_->minute, gps_->seconds);
          // Serial.println(gps_->milliseconds);
          Serial.print(" GPS data\nTime: ");
          Serial.println(tstr);

          Serial.print("Date: ");
          char dstr[32] = "";
          snprintf(dstr, sizeof(dstr), "20%02d-%02d-%02d", gps_->year, gps_->month, gps_->day);
          Serial.println(dstr);

          Serial.print("Fix: ");
          Serial.print((int)gps_->fix);
          Serial.print(" quality: ");
          Serial.println((int)gps_->fixquality);

          if (gps_->fix) {
            Serial.print("Location: ");
            Serial.print(gps_->latitude, 4);
            Serial.print(gps_->lat);
            Serial.print(", ");
            Serial.print(gps_->longitude, 4);
            Serial.println(gps_->lon);
            Serial.print("Location (in degrees, works with Google Maps): ");
            Serial.print(gps_->latitudeDegrees, 4);
            Serial.print(", ");
            Serial.println(gps_->longitudeDegrees, 4);

            Serial.print("Speed (knots): ");
            Serial.println(gps_->speed);
            Serial.print("Angle: ");
            Serial.println(gps_->angle);
            Serial.print("Altitude: ");
            Serial.println(gps_->altitude);
            Serial.print("Satellites: ");
            Serial.println((int)gps_->satellites);
          }
        } else {
          Serial.println(" No GPS data available.");
        }
      }
    }
  }

private:
  void useInterrupt(boolean v) {
    if (v) {
      // Timer0 is already used for millis() - we'll just interrupt somewhere
      // in the middle and call the "Compare A" function above
      OCR0A = 0xAF;
      TIMSK0 |= _BV(OCIE0A);
      usingInterrupt = true;
    } else {
      // do not call the interrupt function COMPA anymore
      TIMSK0 &= ~_BV(OCIE0A);
      usingInterrupt = false;
    }
  }
};

#endif

#ifdef HAVE_PMS
PmSensor pmSensor(60000ul);
#endif

#ifdef HAVE_GPS
SoftwareSerial gpsSerial(2, 3);
GpsSensor gpsSensor(60000ul);
#endif

void setup() {
  // Enable LED
  // LED_BUILTIN is PIN 15 on Moteino MEGA, PIN 9 on Moteino
  pinMode(LED_BUILTIN, OUTPUT);
  openSerialMonitor();

#ifdef HAVE_PMS
  Serial1.begin(9600);
  pmSensor.setup(&Serial1);
#endif

#ifdef HAVE_GPS0
  gpsSerial.begin(9600);
  gpsSensor.setup(&gpsSerial);
#endif
}

void loop() {
#ifdef HAVE_GPS
  gpsSensor.update();
#endif

#ifdef HAVE_PMS
  pmSensor.update();
#endif
}
