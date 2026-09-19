#include <WiFi.h>
#include <WebServer.h>
#include <Preferences.h>
#include <ArduinoJson.h>
#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <BLE2902.h>
#include <Adafruit_NeoPixel.h>
#include <PubSubClient.h>

const char* ap_ssid = "ESP32-Config";
const char* ap_password = "12345678";

String deviceId;
String bleName;

String computeDeviceId() {
  uint64_t mac = ESP.getEfuseMac();
  char buf[7];
  snprintf(buf, sizeof(buf), "%06X", (unsigned int)(mac & 0xFFFFFF));
  return String(buf);
}

#define PIN_SEL_9V  6
#define PIN_SEL_12V 7
#define PIN_SEL_15V 5

#define PIN_LED_DATA 4
#define NUM_LEDS 30
Adafruit_NeoPixel strip(NUM_LEDS, PIN_LED_DATA, NEO_GRB + NEO_KHZ800);

String ledMode = "off";
String customStyle = "chase";
uint8_t ledSpeedPct = 50;
uint8_t ledBrightPct = 80;
uint8_t customR = 0, customG = 240, customB = 255;
int8_t ledDirection = 1;

unsigned long lastLedStep = 0;
uint16_t rainbowStep = 0;
int bouncePos = 0;
int bounceDir = 1;
int chasePos = 0;
int theaterPhase = 0;
int wipePos = 0;
bool wipeFilling = true;
float breathePhase = 0;
float wavePhase = 0;
int meteorPos = 0;
bool strobeOn = false;
bool policeToggle = false;
uint8_t heat[NUM_LEDS];

int lightningTimer = 0;
bool lightningFlash = false;
int dissolveIndex = 0;
bool dissolveFilling = true;
uint8_t dissolveOrder[NUM_LEDS];
bool dissolveOrderInit = false;
float plasmaPhase = 0;
float prideBaseHue = 0;
float fadePhase = 0;
int twoDotsA = 0;
int twoDotsB = NUM_LEDS - 1;
bool twoDotsDirA = true;
bool twoDotsDirB = false;
int lighthousePos = 0;

Preferences preferences;
WebServer server(80);

float currentSetVoltage = 5.0;
unsigned long startMillis = 0;

String savedWifiSsid = "";
String savedWifiPass = "";
bool wifiCredsExist = false;
unsigned long lastWifiRetry = 0;
const unsigned long WIFI_RETRY_INTERVAL = 15000;

const char* mqttBroker = "broker.emqx.io";
const int mqttPort = 1883;
String cmdTopic;
String statusTopic;
WiFiClient espNetClient;
PubSubClient mqttClient(espNetClient);
unsigned long lastMqttRetry = 0;
const unsigned long MQTT_RETRY_INTERVAL = 5000;
unsigned long lastStatusPublish = 0;
const unsigned long STATUS_PUBLISH_INTERVAL = 3000;

#define SERVICE_UUID "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

BLEServer* pServer = NULL;
BLECharacteristic* pCharacteristic = NULL;
bool deviceConnected = false;
volatile bool bleDataReceived = false;
String bleCommand = "";

class MyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    deviceConnected = true;
  }
  void onDisconnect(BLEServer* pServer) {
    deviceConnected = false;

    delay(500);
    pServer->getAdvertising()->start();
  }
};

class MyCharacteristicCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* pCharacteristic) {
    String rxValue = pCharacteristic->getValue();
    if (!rxValue.isEmpty()) {
      bleCommand = rxValue;
      bleDataReceived = true;
    }
  }
};

void applyVoltage(float volt);
void applyLedSettings(String mode, int speed, int brightness, long colorVal, int direction, String style);
void handleLedAnimation();
void renderStaticFrame();
void saveLedPrefs();
void loadLedPrefs();
uint32_t wheelColor(byte pos);
uint32_t customColor();
uint16_t speedDelay(uint16_t slowMs, uint16_t fastMs);
bool isValidMode(String m);
void loadWifiCreds();
void connectWifiSTA(bool firstAttempt);
void reconnectMqttIfNeeded();
void publishStatus();
String formatUptime();
void handleCommandJson(String jsonStr);

const char* VALID_MODES[] = {
  "static", "rainbow_static", "rainbow_chase", "chase", "theater",
  "theater_rainbow", "breathe", "breathe_rainbow", "disco", "bounce",
  "bounce_solid", "fire", "comet", "sparkle", "wave",
  "colorwipe", "strobe", "police", "meteor", "gradient",
  "twinkle", "twinkle_rainbow", "confetti", "cylon", "dual_scan",
  "rain", "fireworks", "plasma", "noise", "lightning",
  "bpm", "juggle", "pride", "fade", "blink",
  "blink_rainbow", "dissolve", "dissolve_rainbow", "running_dual", "traffic_light",
  "halloween", "christmas", "ocean", "aurora", "candle",
  "colorloop", "saw", "multi_comet", "two_dots", "lighthouse"
};
const int VALID_MODES_COUNT = 50;

bool isValidMode(String m) {
  if (m == "off" || m == "custom") return true;
  for (int i = 0; i < VALID_MODES_COUNT; i++) {
    if (m == VALID_MODES[i]) return true;
  }
  return false;
}

void applyVoltage(float volt) {
  if (volt >= 13.5) volt = 15.0;
  else if (volt >= 10.5) volt = 12.0;
  else if (volt >= 7.0) volt = 9.0;
  else volt = 5.0;

  pinMode(PIN_SEL_9V, INPUT);
  pinMode(PIN_SEL_12V, INPUT);
  pinMode(PIN_SEL_15V, INPUT);

  if (volt == 9.0) {
    pinMode(PIN_SEL_9V, OUTPUT);
    digitalWrite(PIN_SEL_9V, LOW);
  } else if (volt == 12.0) {
    pinMode(PIN_SEL_12V, OUTPUT);
    digitalWrite(PIN_SEL_12V, LOW);
  } else if (volt == 15.0) {
    pinMode(PIN_SEL_15V, OUTPUT);
    digitalWrite(PIN_SEL_15V, LOW);
  }
  currentSetVoltage = volt;
}

uint32_t wheelColor(byte pos) {
  pos = 255 - pos;
  if (pos < 85) return strip.Color(255 - pos * 3, 0, pos * 3);
  if (pos < 170) { pos -= 85; return strip.Color(0, pos * 3, 255 - pos * 3); }
  pos -= 170;
  return strip.Color(pos * 3, 255 - pos * 3, 0);
}

uint32_t customColor() {
  return strip.Color(customR, customG, customB);
}

uint16_t speedDelay(uint16_t slowMs, uint16_t fastMs) {
  long v = (long)slowMs - (((long)(slowMs - fastMs) * ledSpeedPct) / 100);
  if (v < fastMs) v = fastMs;
  if (v > slowMs) v = slowMs;
  return (uint16_t)v;
}

void fillSolid(uint32_t c) {
  for (int i = 0; i < NUM_LEDS; i++) strip.setPixelColor(i, c);
}

uint32_t heatColor(uint8_t t) {
  uint8_t t192 = (uint8_t)((t / 255.0) * 191);
  uint8_t heatramp = (t192 & 0x3F) << 2;
  if (t192 > 128) return strip.Color(255, 255, heatramp);
  else if (t192 > 64) return strip.Color(255, heatramp, 0);
  else return strip.Color(heatramp, 0, 0);
}

void renderStaticFrame() {
  if (ledMode == "off") {
    strip.clear();
    strip.show();
  } else if (ledMode == "static") {
    fillSolid(customColor());
    strip.show();
  } else if (ledMode == "rainbow_static") {
    for (int i = 0; i < NUM_LEDS; i++) {
      int hue = (i * 256 / NUM_LEDS) & 255;
      strip.setPixelColor(i, wheelColor(hue));
    }
    strip.show();
  } else if (ledMode == "gradient") {
    uint32_t c1 = customColor();
    for (int i = 0; i < NUM_LEDS; i++) {
      float f = (float)i / (NUM_LEDS - 1);
      uint8_t r = (uint8_t)(((c1 >> 16) & 0xFF) * (1 - f) + 255 * f);
      uint8_t g = (uint8_t)(((c1 >> 8) & 0xFF) * (1 - f) + 255 * f);
      uint8_t b = (uint8_t)((c1 & 0xFF) * (1 - f) + 255 * f);
      strip.setPixelColor(i, strip.Color(r, g, b));
    }
    strip.show();
  } else if (ledMode == "custom" && customStyle == "static") {
    fillSolid(customColor());
    strip.show();
  }
}

void doChase(bool rainbow) {
  uint16_t interval = speedDelay(90, 12);
  if (millis() - lastLedStep < interval) return;
  lastLedStep = millis();
  strip.clear();
  const int tailLen = 6;
  for (int t = 0; t < tailLen; t++) {
    int pos = ((chasePos - (ledDirection * t)) % NUM_LEDS + NUM_LEDS) % NUM_LEDS;
    int fade = 255 - (t * (255 / tailLen));
    uint32_t c = rainbow ? wheelColor((chasePos * 6) & 255) : customColor();
    uint8_t r = (uint8_t)(((c >> 16) & 0xFF) * fade / 255);
    uint8_t g = (uint8_t)(((c >> 8) & 0xFF) * fade / 255);
    uint8_t b = (uint8_t)((c & 0xFF) * fade / 255);
    strip.setPixelColor(pos, strip.Color(r, g, b));
  }
  strip.show();
  chasePos = (chasePos + ledDirection + NUM_LEDS) % NUM_LEDS;
}

void doTheater(bool rainbow) {
  uint16_t interval = speedDelay(160, 40);
  if (millis() - lastLedStep < interval) return;
  lastLedStep = millis();
  strip.clear();
  for (int i = 0; i < NUM_LEDS; i++) {
    if (((i + theaterPhase) % 3 + 3) % 3 == 0) {
      uint32_t c = rainbow ? wheelColor((i * 8 + theaterPhase * 10) & 255) : customColor();
      strip.setPixelColor(i, c);
    }
  }
  strip.show();
  theaterPhase = (theaterPhase + ledDirection + 3) % 3;
}

void doBreathe(bool rainbow) {
  if (millis() - lastLedStep < 20) return;
  lastLedStep = millis();
  breathePhase += 0.015 + (ledSpeedPct / 100.0) * 0.09;
  if (breathePhase > 2 * PI) breathePhase -= 2 * PI;
  float b = (sin(breathePhase) + 1) / 2.0;
  uint32_t base = rainbow ? wheelColor(((int)(breathePhase * 40)) & 255) : customColor();
  uint8_t r = (uint8_t)(((base >> 16) & 0xFF) * b);
  uint8_t g = (uint8_t)(((base >> 8) & 0xFF) * b);
  uint8_t bl = (uint8_t)((base & 0xFF) * b);
  uint32_t c = strip.Color(r, g, bl);
  fillSolid(c);
  strip.show();
}

void doBounce(bool rainbow) {
  uint16_t interval = speedDelay(70, 10);
  if (millis() - lastLedStep < interval) return;
  lastLedStep = millis();
  strip.clear();
  const int tailLen = 4;
  for (int t = 0; t < tailLen; t++) {
    int pos = bouncePos - (bounceDir * t);
    if (pos >= 0 && pos < NUM_LEDS) {
      int fade = 255 - (t * (255 / tailLen));
      uint32_t c = rainbow ? wheelColor((bouncePos * 8) & 255) : customColor();
      uint8_t r = (uint8_t)(((c >> 16) & 0xFF) * fade / 255);
      uint8_t g = (uint8_t)(((c >> 8) & 0xFF) * fade / 255);
      uint8_t b = (uint8_t)((c & 0xFF) * fade / 255);
      strip.setPixelColor(pos, strip.Color(r, g, b));
    }
  }
  strip.show();
  bouncePos += bounceDir;
  if (bouncePos >= NUM_LEDS - 1 || bouncePos <= 0) bounceDir = -bounceDir;
}

void doComet(bool rainbow) {
  uint16_t interval = speedDelay(60, 8);
  if (millis() - lastLedStep < interval) return;
  lastLedStep = millis();
  strip.clear();
  const int tailLen = 9;
  for (int t = 0; t < tailLen; t++) {
    int pos = ((chasePos - (ledDirection * t)) % NUM_LEDS + NUM_LEDS) % NUM_LEDS;
    float fadeF = 1.0 - (float)(t * t) / (float)(tailLen * tailLen);
    if (fadeF < 0) fadeF = 0;
    uint32_t c = rainbow ? wheelColor((rainbowStep + t * 4) & 255) : customColor();
    uint8_t r = (uint8_t)(((c >> 16) & 0xFF) * fadeF);
    uint8_t g = (uint8_t)(((c >> 8) & 0xFF) * fadeF);
    uint8_t b = (uint8_t)((c & 0xFF) * fadeF);
    strip.setPixelColor(pos, strip.Color(r, g, b));
  }
  strip.show();
  chasePos = (chasePos + ledDirection + NUM_LEDS) % NUM_LEDS;
  rainbowStep = (rainbowStep + 2) % 256;
}

void doMeteor() {
  uint16_t interval = speedDelay(50, 6);
  if (millis() - lastLedStep < interval) return;
  lastLedStep = millis();
  for (int i = 0; i < NUM_LEDS; i++) {
    uint32_t c = strip.getPixelColor(i);
    uint8_t r = (uint8_t)(((c >> 16) & 0xFF) * 0.72);
    uint8_t g = (uint8_t)(((c >> 8) & 0xFF) * 0.72);
    uint8_t b = (uint8_t)((c & 0xFF) * 0.72);
    strip.setPixelColor(i, strip.Color(r, g, b));
  }
  uint32_t headC = customColor();
  for (int j = 0; j < 3; j++) {
    int pos = ((meteorPos - (ledDirection * j)) % NUM_LEDS + NUM_LEDS) % NUM_LEDS;
    strip.setPixelColor(pos, headC);
  }
  strip.show();
  meteorPos = (meteorPos + ledDirection + NUM_LEDS) % NUM_LEDS;
}

void doWave() {
  uint16_t interval = speedDelay(60, 10);
  if (millis() - lastLedStep < interval) return;
  lastLedStep = millis();
  uint32_t base = customColor();
  uint8_t br = (base >> 16) & 0xFF, bg = (base >> 8) & 0xFF, bb = base & 0xFF;
  for (int i = 0; i < NUM_LEDS; i++) {
    float phase = (i * 0.35) + wavePhase;
    float b = (sin(phase) + 1) / 2.0;
    strip.setPixelColor(i, strip.Color((uint8_t)(br * b), (uint8_t)(bg * b), (uint8_t)(bb * b)));
  }
  strip.show();
  wavePhase += 0.15 * ledDirection;
}

void doColorWipe() {
  uint16_t interval = speedDelay(70, 10);
  if (millis() - lastLedStep < interval) return;
  lastLedStep = millis();
  int idx = wipeFilling ? wipePos : (NUM_LEDS - 1 - wipePos);
  int realIdx = ledDirection >= 0 ? idx : (NUM_LEDS - 1 - idx);
  strip.setPixelColor(realIdx, wipeFilling ? customColor() : strip.Color(0, 0, 0));
  strip.show();
  wipePos++;
  if (wipePos >= NUM_LEDS) {
    wipePos = 0;
    wipeFilling = !wipeFilling;
  }
}

void doSparkle() {
  uint16_t interval = speedDelay(120, 15);
  if (millis() - lastLedStep < interval) return;
  lastLedStep = millis();
  for (int i = 0; i < NUM_LEDS; i++) {
    uint32_t c = strip.getPixelColor(i);
    uint8_t r = (uint8_t)(((c >> 16) & 0xFF) * 0.85);
    uint8_t g = (uint8_t)(((c >> 8) & 0xFF) * 0.85);
    uint8_t b = (uint8_t)((c & 0xFF) * 0.85);
    strip.setPixelColor(i, strip.Color(r, g, b));
  }
  int spark = random(0, NUM_LEDS);
  strip.setPixelColor(spark, customColor());
  strip.show();
}

void doStrobe() {
  uint16_t interval = speedDelay(400, 40);
  if (millis() - lastLedStep < interval) return;
  lastLedStep = millis();
  strobeOn = !strobeOn;
  uint32_t c = strobeOn ? customColor() : strip.Color(0, 0, 0);
  fillSolid(c);
  strip.show();
}

void doPolice() {
  uint16_t interval = speedDelay(260, 40);
  if (millis() - lastLedStep < interval) return;
  lastLedStep = millis();
  policeToggle = !policeToggle;
  uint32_t red = strip.Color(255, 0, 0);
  uint32_t blue = strip.Color(0, 60, 255);
  int half = NUM_LEDS / 2;
  for (int i = 0; i < NUM_LEDS; i++) {
    bool firstHalf = i < half;
    bool lit = policeToggle ? firstHalf : !firstHalf;
    strip.setPixelColor(i, lit ? (firstHalf ? red : blue) : strip.Color(0, 0, 0));
  }
  strip.show();
}

void doFire() {
  uint16_t interval = speedDelay(60, 15);
  if (millis() - lastLedStep < interval) return;
  lastLedStep = millis();
  int cooling = 55;
  int sparking = 120;
  for (int i = 0; i < NUM_LEDS; i++) {
    int cooldown = random(0, ((cooling * 10) / NUM_LEDS) + 2);
    heat[i] = (heat[i] <= cooldown) ? 0 : heat[i] - cooldown;
  }
  for (int k = NUM_LEDS - 1; k >= 2; k--) {
    heat[k] = (heat[k - 1] + heat[k - 2] + heat[k - 2]) / 3;
  }
  if (random(255) < sparking) {
    int y = random(0, 3);
    heat[y] = min(255, (int)(heat[y] + random(160, 255)));
  }
  for (int i = 0; i < NUM_LEDS; i++) {
    strip.setPixelColor(i, heatColor(heat[i]));
  }
  strip.show();
}

void doDisco() {
  uint16_t interval = speedDelay(300, 60);
  if (millis() - lastLedStep < interval) return;
  lastLedStep = millis();
  for (int i = 0; i < NUM_LEDS; i++) {
    strip.setPixelColor(i, strip.Color(random(0, 256), random(0, 256), random(0, 256)));
  }
  strip.show();
}

void doStaticColor() {
  if (millis() - lastLedStep < 200) return;
  lastLedStep = millis();
  fillSolid(customColor());
  strip.show();
}

void fadeAll(uint8_t amount) {
  for (int i = 0; i < NUM_LEDS; i++) {
    uint32_t c = strip.getPixelColor(i);
    uint8_t r = (uint8_t)(((c >> 16) & 0xFF) * (255 - amount) / 255);
    uint8_t g = (uint8_t)(((c >> 8) & 0xFF) * (255 - amount) / 255);
    uint8_t b = (uint8_t)((c & 0xFF) * (255 - amount) / 255);
    strip.setPixelColor(i, strip.Color(r, g, b));
  }
}

void doTwinkle(bool rainbow) {
  uint16_t interval = speedDelay(90, 10);
  if (millis() - lastLedStep < interval) return;
  lastLedStep = millis();
  fadeAll(40);
  if (random(0, 100) < 55) {
    int pos = random(0, NUM_LEDS);
    uint32_t c = rainbow ? wheelColor(random(0, 256)) : customColor();
    strip.setPixelColor(pos, c);
  }
  strip.show();
}

void doConfetti() {
  uint16_t interval = speedDelay(90, 10);
  if (millis() - lastLedStep < interval) return;
  lastLedStep = millis();
  fadeAll(25);
  if (random(0, 100) < 60) {
    int pos = random(0, NUM_LEDS);
    strip.setPixelColor(pos, wheelColor(random(0, 256)));
  }
  strip.show();
}

void doCylon(bool rainbow) {
  uint16_t interval = speedDelay(45, 6);
  if (millis() - lastLedStep < interval) return;
  lastLedStep = millis();
  strip.clear();
  const int eyeSize = 3;
  uint32_t c = rainbow ? wheelColor((bouncePos * 6) & 255) : customColor();
  for (int i = 0; i < eyeSize; i++) {
    int pos = bouncePos + i;
    if (pos >= 0 && pos < NUM_LEDS) strip.setPixelColor(pos, c);
  }
  strip.show();
  bouncePos += bounceDir;
  if (bouncePos >= NUM_LEDS - eyeSize || bouncePos <= 0) bounceDir = -bounceDir;
}

void doDualScan(bool rainbow) {
  uint16_t interval = speedDelay(45, 6);
  if (millis() - lastLedStep < interval) return;
  lastLedStep = millis();
  strip.clear();
  uint32_t c = rainbow ? wheelColor((bouncePos * 8) & 255) : customColor();
  strip.setPixelColor(bouncePos, c);
  strip.setPixelColor(NUM_LEDS - 1 - bouncePos, c);
  strip.show();
  bouncePos += bounceDir;
  if (bouncePos >= NUM_LEDS - 1 || bouncePos <= 0) bounceDir = -bounceDir;
}

void doRain(bool rainbow) {
  uint16_t interval = speedDelay(70, 8);
  if (millis() - lastLedStep < interval) return;
  lastLedStep = millis();
  uint32_t drop = (random(0, 100) < 40) ? (rainbow ? wheelColor(random(0, 256)) : customColor()) : strip.Color(0, 0, 0);
  if (ledDirection >= 0) {
    for (int i = NUM_LEDS - 1; i > 0; i--) strip.setPixelColor(i, strip.getPixelColor(i - 1));
    strip.setPixelColor(0, drop);
  } else {
    for (int i = 0; i < NUM_LEDS - 1; i++) strip.setPixelColor(i, strip.getPixelColor(i + 1));
    strip.setPixelColor(NUM_LEDS - 1, drop);
  }
  strip.show();
}

void doFireworks(bool rainbow) {
  uint16_t interval = speedDelay(60, 10);
  if (millis() - lastLedStep < interval) return;
  lastLedStep = millis();
  fadeAll(30);
  if (random(0, 100) < 12) {
    int center = random(2, NUM_LEDS - 2);
    uint32_t c = rainbow ? wheelColor(random(0, 256)) : customColor();
    strip.setPixelColor(center, c);
    strip.setPixelColor(center - 1, c);
    strip.setPixelColor(center + 1, c);
  }
  strip.show();
}

void doPlasma() {
  if (millis() - lastLedStep < 20) return;
  lastLedStep = millis();
  plasmaPhase += 0.04 + (ledSpeedPct / 100.0) * 0.12;
  for (int i = 0; i < NUM_LEDS; i++) {
    float v = sin(i * 0.3 + plasmaPhase) + sin(i * 0.15 - plasmaPhase * 1.3) + sin(plasmaPhase * 0.7);
    uint8_t hue = (uint8_t)(((v + 3.0) / 6.0) * 255);
    strip.setPixelColor(i, wheelColor(hue));
  }
  strip.show();
}

void doNoise() {
  if (millis() - lastLedStep < 25) return;
  lastLedStep = millis();
  wavePhase += 0.02 + (ledSpeedPct / 100.0) * 0.08;
  uint32_t base = customColor();
  for (int i = 0; i < NUM_LEDS; i++) {
    float n = (sin(i * 0.5 + wavePhase) * sin(i * 0.23 - wavePhase * 0.7) + 1) / 2.0;
    strip.setPixelColor(i, strip.Color(
      (uint8_t)(((base >> 16) & 0xFF) * n),
      (uint8_t)(((base >> 8) & 0xFF) * n),
      (uint8_t)((base & 0xFF) * n)));
  }
  strip.show();
}

void doLightning() {
  if (millis() - lastLedStep < 30) return;
  lastLedStep = millis();
  if (lightningTimer <= 0) {
    if (random(0, 100) < 6) {
      lightningFlash = true;
      lightningTimer = random(2, 5);
      fillSolid(strip.Color(255, 255, 255));
    } else {
      strip.clear();
    }
  } else {
    lightningTimer--;
    fillSolid(random(0, 100) < 50 ? strip.Color(255, 255, 255) : strip.Color(0, 0, 0));
    if (lightningTimer <= 0) {
      lightningFlash = false;
      strip.clear();
    }
  }
  strip.show();
}

void doBpm() {
  if (millis() - lastLedStep < 20) return;
  lastLedStep = millis();
  breathePhase += 0.02 + (ledSpeedPct / 100.0) * 0.18;
  if (breathePhase > 2 * PI) breathePhase -= 2 * PI;
  for (int i = 0; i < NUM_LEDS; i++) {
    float b = (sin(breathePhase + i * 0.2) + 1) / 2.0;
    uint32_t c = wheelColor((uint8_t)((i * 8 + millis() / 20) & 255));
    float lvl = 0.3 + 0.7 * b;
    strip.setPixelColor(i, strip.Color(
      (uint8_t)(((c >> 16) & 0xFF) * lvl),
      (uint8_t)(((c >> 8) & 0xFF) * lvl),
      (uint8_t)((c & 0xFF) * lvl)));
  }
  strip.show();
}

void doJuggle() {
  if (millis() - lastLedStep < 20) return;
  lastLedStep = millis();
  fadeAll(45);
  float t = millis() / 1000.0 * (0.3 + (ledSpeedPct / 100.0) * 1.2);
  for (int j = 0; j < 3; j++) {
    float phase = t * (1.0 + j * 0.4) + j * 2.1;
    int pos = (int)(((sin(phase) + 1) / 2.0) * (NUM_LEDS - 1));
    strip.setPixelColor(pos, wheelColor((uint8_t)((j * 85 + millis() / 10) & 255)));
  }
  strip.show();
}

void doPride() {
  if (millis() - lastLedStep < 20) return;
  lastLedStep = millis();
  prideBaseHue += 0.3 + (ledSpeedPct / 100.0) * 1.2;
  for (int i = 0; i < NUM_LEDS; i++) {
    uint8_t hue = (uint8_t)((int)(prideBaseHue + i * 6) & 255);
    strip.setPixelColor(i, wheelColor(hue));
  }
  strip.show();
}

void doFadeMode() {
  if (millis() - lastLedStep < 20) return;
  lastLedStep = millis();
  fadePhase += 0.01 + (ledSpeedPct / 100.0) * 0.05;
  float b = (sin(fadePhase) + 1) / 2.0;
  uint32_t c1 = customColor();
  uint32_t c2 = wheelColor((uint8_t)((int)(fadePhase * 40) & 255));
  uint8_t r = (uint8_t)(((c1 >> 16) & 0xFF) * (1 - b) + ((c2 >> 16) & 0xFF) * b);
  uint8_t g = (uint8_t)(((c1 >> 8) & 0xFF) * (1 - b) + ((c2 >> 8) & 0xFF) * b);
  uint8_t bl = (uint8_t)((c1 & 0xFF) * (1 - b) + (c2 & 0xFF) * b);
  fillSolid(strip.Color(r, g, bl));
  strip.show();
}

void doBlink(bool rainbow) {
  uint16_t interval = speedDelay(500, 80);
  if (millis() - lastLedStep < interval) return;
  lastLedStep = millis();
  strobeOn = !strobeOn;
  if (strobeOn) {
    uint32_t c = rainbow ? wheelColor(rainbowStep) : customColor();
    fillSolid(c);
    if (rainbow) rainbowStep = (rainbowStep + 32) % 256;
  } else {
    strip.clear();
  }
  strip.show();
}

void doDissolve(bool rainbow) {
  uint16_t interval = speedDelay(40, 4);
  if (millis() - lastLedStep < interval) return;
  lastLedStep = millis();
  if (!dissolveOrderInit) {
    for (int i = 0; i < NUM_LEDS; i++) dissolveOrder[i] = i;
    for (int i = NUM_LEDS - 1; i > 0; i--) {
      int j = random(0, i + 1);
      uint8_t tmp = dissolveOrder[i]; dissolveOrder[i] = dissolveOrder[j]; dissolveOrder[j] = tmp;
    }
    dissolveOrderInit = true;
  }
  int idx = dissolveOrder[dissolveIndex];
  uint32_t c = dissolveFilling ? (rainbow ? wheelColor(random(0, 256)) : customColor()) : strip.Color(0, 0, 0);
  strip.setPixelColor(idx, c);
  strip.show();
  dissolveIndex++;
  if (dissolveIndex >= NUM_LEDS) {
    dissolveIndex = 0;
    dissolveFilling = !dissolveFilling;
    for (int i = NUM_LEDS - 1; i > 0; i--) {
      int j = random(0, i + 1);
      uint8_t tmp = dissolveOrder[i]; dissolveOrder[i] = dissolveOrder[j]; dissolveOrder[j] = tmp;
    }
  }
}

void doRunningDual() {
  uint16_t interval = speedDelay(80, 10);
  if (millis() - lastLedStep < interval) return;
  lastLedStep = millis();
  strip.clear();
  int posA = chasePos % NUM_LEDS;
  int posB = (NUM_LEDS - 1 - chasePos + NUM_LEDS) % NUM_LEDS;
  strip.setPixelColor(posA, customColor());
  strip.setPixelColor(posB, wheelColor((chasePos * 10) & 255));
  strip.show();
  chasePos = (chasePos + 1) % NUM_LEDS;
}

void doTrafficLight() {
  uint16_t interval = speedDelay(900, 200);
  if (millis() - lastLedStep < interval) return;
  lastLedStep = millis();
  theaterPhase = (theaterPhase + 1) % 3;
  uint32_t red = strip.Color(255, 0, 0), yellow = strip.Color(255, 160, 0), green = strip.Color(0, 255, 60);
  fillSolid(theaterPhase == 0 ? red : (theaterPhase == 1 ? yellow : green));
  strip.show();
}

void doHalloween() {
  uint16_t interval = speedDelay(160, 30);
  if (millis() - lastLedStep < interval) return;
  lastLedStep = millis();
  uint32_t purple = strip.Color(140, 0, 200), orange = strip.Color(255, 90, 0);
  for (int i = 0; i < NUM_LEDS; i++) {
    bool purpleSlot = ((i + chasePos) % 4) < 2;
    strip.setPixelColor(i, purpleSlot ? purple : orange);
  }
  strip.show();
  chasePos = (chasePos + ledDirection + NUM_LEDS) % NUM_LEDS;
}

void doChristmas() {
  uint16_t interval = speedDelay(160, 30);
  if (millis() - lastLedStep < interval) return;
  lastLedStep = millis();
  uint32_t red = strip.Color(255, 0, 0), green = strip.Color(0, 200, 40);
  for (int i = 0; i < NUM_LEDS; i++) {
    bool redSlot = ((i + chasePos) % 2) == 0;
    strip.setPixelColor(i, redSlot ? red : green);
  }
  strip.show();
  chasePos = (chasePos + ledDirection + NUM_LEDS) % NUM_LEDS;
}

void doOcean() {
  if (millis() - lastLedStep < 30) return;
  lastLedStep = millis();
  wavePhase += 0.05 + (ledSpeedPct / 100.0) * 0.15;
  for (int i = 0; i < NUM_LEDS; i++) {
    float b = (sin(i * 0.4 + wavePhase) + 1) / 2.0;
    uint8_t bl = (uint8_t)(150 + 105 * b);
    uint8_t g = (uint8_t)(80 + 100 * b);
    strip.setPixelColor(i, strip.Color(0, g, bl));
  }
  strip.show();
}

void doAurora() {
  if (millis() - lastLedStep < 30) return;
  lastLedStep = millis();
  wavePhase += 0.03 + (ledSpeedPct / 100.0) * 0.1;
  for (int i = 0; i < NUM_LEDS; i++) {
    float p1 = sin(i * 0.3 + wavePhase);
    float p2 = sin(i * 0.2 - wavePhase * 0.6);
    uint8_t hue = (uint8_t)(100 + p1 * 40 + p2 * 20);
    uint8_t br = (uint8_t)(((p1 + p2 + 2) / 4.0) * 255);
    uint32_t c = wheelColor(hue);
    strip.setPixelColor(i, strip.Color(
      (uint8_t)(((c >> 16) & 0xFF) * br / 255),
      (uint8_t)(((c >> 8) & 0xFF) * br / 255),
      (uint8_t)((c & 0xFF) * br / 255)));
  }
  strip.show();
}

void doCandle() {
  if (millis() - lastLedStep < 40) return;
  lastLedStep = millis();
  for (int i = 0; i < NUM_LEDS; i++) {
    int flicker = random(-25, 25);
    uint8_t r = constrain(220 + flicker, 120, 255);
    uint8_t g = constrain(110 + flicker / 2, 40, 170);
    strip.setPixelColor(i, strip.Color(r, g, 0));
  }
  strip.show();
}

void doColorloop() {
  if (millis() - lastLedStep < 30) return;
  lastLedStep = millis();
  rainbowStep = (rainbowStep + 1) % 256;
  uint16_t spd = map(ledSpeedPct, 0, 100, 1, 6);
  fillSolid(wheelColor((uint8_t)((rainbowStep * spd) & 255)));
  strip.show();
}

void doSaw() {
  if (millis() - lastLedStep < 20) return;
  lastLedStep = millis();
  wavePhase += 0.02 + (ledSpeedPct / 100.0) * 0.08;
  float frac = wavePhase - floor(wavePhase);
  uint32_t base = customColor();
  uint8_t br = (base >> 16) & 0xFF, bg = (base >> 8) & 0xFF, bb = base & 0xFF;
  fillSolid(strip.Color((uint8_t)(br * frac), (uint8_t)(bg * frac), (uint8_t)(bb * frac)));
  strip.show();
}

void doMultiComet(bool rainbow) {
  uint16_t interval = speedDelay(55, 8);
  if (millis() - lastLedStep < interval) return;
  lastLedStep = millis();
  strip.clear();
  const int tailLen = 5;
  const int numComets = 3;
  for (int cIdx = 0; cIdx < numComets; cIdx++) {
    int base = (chasePos + cIdx * (NUM_LEDS / numComets)) % NUM_LEDS;
    for (int t = 0; t < tailLen; t++) {
      int pos = ((base - (ledDirection * t)) % NUM_LEDS + NUM_LEDS) % NUM_LEDS;
      float fadeF = 1.0 - (float)t / tailLen;
      uint32_t c = rainbow ? wheelColor((cIdx * 85 + rainbowStep) & 255) : customColor();
      uint8_t r = (uint8_t)(((c >> 16) & 0xFF) * fadeF);
      uint8_t g = (uint8_t)(((c >> 8) & 0xFF) * fadeF);
      uint8_t b = (uint8_t)((c & 0xFF) * fadeF);
      strip.setPixelColor(pos, strip.Color(r, g, b));
    }
  }
  strip.show();
  chasePos = (chasePos + ledDirection + NUM_LEDS) % NUM_LEDS;
  rainbowStep = (rainbowStep + 3) % 256;
}

void doTwoDots() {
  uint16_t interval = speedDelay(70, 10);
  if (millis() - lastLedStep < interval) return;
  lastLedStep = millis();
  strip.clear();
  strip.setPixelColor(twoDotsA, customColor());
  strip.setPixelColor(twoDotsB, wheelColor(128));
  strip.show();
  twoDotsA += (twoDotsDirA ? 1 : -1);
  twoDotsB += (twoDotsDirB ? 1 : -1);
  if (twoDotsA >= NUM_LEDS - 1 || twoDotsA <= 0) twoDotsDirA = !twoDotsDirA;
  if (twoDotsB >= NUM_LEDS - 1 || twoDotsB <= 0) twoDotsDirB = !twoDotsDirB;
}

void doLighthouse() {
  uint16_t interval = speedDelay(70, 8);
  if (millis() - lastLedStep < interval) return;
  lastLedStep = millis();
  uint32_t base = customColor();
  uint8_t dimR = ((base >> 16) & 0xFF) / 10, dimG = ((base >> 8) & 0xFF) / 10, dimB = (base & 0xFF) / 10;
  fillSolid(strip.Color(dimR, dimG, dimB));
  const int beamWidth = 4;
  for (int t = 0; t < beamWidth; t++) {
    int pos = (lighthousePos + t) % NUM_LEDS;
    float fadeF = 1.0 - (float)t / beamWidth;
    uint8_t r = (uint8_t)(((base >> 16) & 0xFF) * fadeF);
    uint8_t g = (uint8_t)(((base >> 8) & 0xFF) * fadeF);
    uint8_t b = (uint8_t)((base & 0xFF) * fadeF);
    strip.setPixelColor(pos, strip.Color(r, g, b));
  }
  strip.show();
  lighthousePos = (lighthousePos + ledDirection + NUM_LEDS) % NUM_LEDS;
}

void handleLedAnimation() {
  if (ledMode == "off" || ledMode == "static" || ledMode == "rainbow_static" || ledMode == "gradient") return;

  if (ledMode == "rainbow_chase") { doChase(true); return; }
  if (ledMode == "chase") { doChase(false); return; }
  if (ledMode == "theater") { doTheater(false); return; }
  if (ledMode == "theater_rainbow") { doTheater(true); return; }
  if (ledMode == "breathe") { doBreathe(false); return; }
  if (ledMode == "breathe_rainbow") { doBreathe(true); return; }
  if (ledMode == "disco") { doDisco(); return; }
  if (ledMode == "bounce") { doBounce(true); return; }
  if (ledMode == "bounce_solid") { doBounce(false); return; }
  if (ledMode == "fire") { doFire(); return; }
  if (ledMode == "comet") { doComet(true); return; }
  if (ledMode == "sparkle") { doSparkle(); return; }
  if (ledMode == "wave") { doWave(); return; }
  if (ledMode == "colorwipe") { doColorWipe(); return; }
  if (ledMode == "strobe") { doStrobe(); return; }
  if (ledMode == "police") { doPolice(); return; }
  if (ledMode == "meteor") { doMeteor(); return; }

  if (ledMode == "twinkle") { doTwinkle(false); return; }
  if (ledMode == "twinkle_rainbow") { doTwinkle(true); return; }
  if (ledMode == "confetti") { doConfetti(); return; }
  if (ledMode == "cylon") { doCylon(false); return; }
  if (ledMode == "dual_scan") { doDualScan(false); return; }
  if (ledMode == "rain") { doRain(false); return; }
  if (ledMode == "fireworks") { doFireworks(true); return; }
  if (ledMode == "plasma") { doPlasma(); return; }
  if (ledMode == "noise") { doNoise(); return; }
  if (ledMode == "lightning") { doLightning(); return; }
  if (ledMode == "bpm") { doBpm(); return; }
  if (ledMode == "juggle") { doJuggle(); return; }
  if (ledMode == "pride") { doPride(); return; }
  if (ledMode == "fade") { doFadeMode(); return; }
  if (ledMode == "blink") { doBlink(false); return; }
  if (ledMode == "blink_rainbow") { doBlink(true); return; }
  if (ledMode == "dissolve") { doDissolve(false); return; }
  if (ledMode == "dissolve_rainbow") { doDissolve(true); return; }
  if (ledMode == "running_dual") { doRunningDual(); return; }
  if (ledMode == "traffic_light") { doTrafficLight(); return; }
  if (ledMode == "halloween") { doHalloween(); return; }
  if (ledMode == "christmas") { doChristmas(); return; }
  if (ledMode == "ocean") { doOcean(); return; }
  if (ledMode == "aurora") { doAurora(); return; }
  if (ledMode == "candle") { doCandle(); return; }
  if (ledMode == "colorloop") { doColorloop(); return; }
  if (ledMode == "saw") { doSaw(); return; }
  if (ledMode == "multi_comet") { doMultiComet(true); return; }
  if (ledMode == "two_dots") { doTwoDots(); return; }
  if (ledMode == "lighthouse") { doLighthouse(); return; }

  if (ledMode == "custom") {
    if (customStyle == "chase") doChase(false);
    else if (customStyle == "theater") doTheater(false);
    else if (customStyle == "breathe") doBreathe(false);
    else if (customStyle == "comet") doComet(false);
    else if (customStyle == "wave") doWave();
    else if (customStyle == "meteor") doMeteor();
    else if (customStyle == "sparkle") doSparkle();
    else doStaticColor();
  }
}

void saveLedPrefs() {
  preferences.begin("led", false);
  preferences.putString("mode", ledMode);
  preferences.putString("style", customStyle);
  preferences.putUChar("spd", ledSpeedPct);
  preferences.putUChar("bri", ledBrightPct);
  preferences.putUChar("cr", customR);
  preferences.putUChar("cg", customG);
  preferences.putUChar("cb", customB);
  preferences.putChar("dir", ledDirection);
  preferences.end();
}

void loadLedPrefs() {
  preferences.begin("led", true);
  ledMode = preferences.getString("mode", "off");
  customStyle = preferences.getString("style", "chase");
  ledSpeedPct = preferences.getUChar("spd", 50);
  ledBrightPct = preferences.getUChar("bri", 80);
  customR = preferences.getUChar("cr", 0);
  customG = preferences.getUChar("cg", 240);
  customB = preferences.getUChar("cb", 255);
  ledDirection = preferences.getChar("dir", 1);
  preferences.end();
  if (!isValidMode(ledMode)) ledMode = "off";
}

void applyLedSettings(String mode, int speed, int brightness, long colorVal, int direction, String style) {
  bool modeChanged = (mode.length() > 0 && mode != ledMode);
  if (mode.length() > 0 && isValidMode(mode)) ledMode = mode;
  if (style.length() > 0) customStyle = style;
  if (speed >= 0) ledSpeedPct = (uint8_t)constrain(speed, 0, 100);
  if (brightness >= 0) {
    ledBrightPct = (uint8_t)constrain(brightness, 0, 100);
    strip.setBrightness(map(ledBrightPct, 0, 100, 0, 255));
  }
  if (colorVal >= 0) {
    customR = (colorVal >> 16) & 0xFF;
    customG = (colorVal >> 8) & 0xFF;
    customB = colorVal & 0xFF;
  }
  if (direction != 0) ledDirection = (direction >= 1) ? 1 : -1;

  if (modeChanged) {
    rainbowStep = 0;
    bouncePos = 0;
    bounceDir = 1;
    chasePos = 0;
    theaterPhase = 0;
    wipePos = 0;
    wipeFilling = true;
    breathePhase = 0;
    wavePhase = 0;
    meteorPos = 0;
    lastLedStep = 0;
    strobeOn = false;
    policeToggle = false;
    lightningTimer = 0;
    lightningFlash = false;
    dissolveIndex = 0;
    dissolveFilling = true;
    dissolveOrderInit = false;
    plasmaPhase = 0;
    prideBaseHue = 0;
    fadePhase = 0;
    twoDotsA = 0;
    twoDotsB = NUM_LEDS - 1;
    twoDotsDirA = true;
    twoDotsDirB = false;
    lighthousePos = 0;
    for (int i = 0; i < NUM_LEDS; i++) heat[i] = 0;
  }

  renderStaticFrame();
  saveLedPrefs();
}

String formatUptime() {
  unsigned long sec = (millis() - startMillis) / 1000;
  unsigned long h = sec / 3600;
  unsigned long m = (sec % 3600) / 60;
  unsigned long s = sec % 60;
  char buf[12];
  snprintf(buf, sizeof(buf), "%02lu:%02lu:%02lu", h, m, s);
  return String(buf);
}

void loadWifiCreds() {
  preferences.begin("wifi", true);
  savedWifiSsid = preferences.getString("ssid", "");
  savedWifiPass = preferences.getString("pass", "");
  preferences.end();
  wifiCredsExist = savedWifiSsid.length() > 0;
}

void connectWifiSTA(bool firstAttempt) {
  if (!wifiCredsExist) return;
  WiFi.begin(savedWifiSsid.c_str(), savedWifiPass.c_str());
  if (firstAttempt) {

    unsigned long start = millis();
    while (WiFi.status() != WL_CONNECTED && millis() - start < 8000) {
      delay(200);
    }
  }
}

void mqttMessageReceived(char* topic, byte* payload, unsigned int length) {
  String msg;
  msg.reserve(length);
  for (unsigned int i = 0; i < length; i++) msg += (char)payload[i];
  handleCommandJson(msg);
}

void reconnectMqttIfNeeded() {
  if (WiFi.status() != WL_CONNECTED) return;
  if (mqttClient.connected()) return;
  if (millis() - lastMqttRetry < MQTT_RETRY_INTERVAL) return;
  lastMqttRetry = millis();
  String clientId = "esp32-" + deviceId;
  if (mqttClient.connect(clientId.c_str())) {
    mqttClient.subscribe(cmdTopic.c_str());
    publishStatus();
  }
}

void publishStatus() {
  if (!mqttClient.connected()) return;
  StaticJsonDocument<384> doc;
  doc["deviceId"] = deviceId;
  doc["setVoltage"] = currentSetVoltage;
  doc["ledMode"] = ledMode;
  doc["uptime"] = formatUptime();
  doc["speed"] = ledSpeedPct;
  doc["brightness"] = ledBrightPct;
  char hexBuf[8];
  snprintf(hexBuf, sizeof(hexBuf), "%02X%02X%02X", customR, customG, customB);
  doc["color"] = String(hexBuf);
  doc["direction"] = ledDirection;
  doc["customStyle"] = customStyle;
  String out;
  serializeJson(doc, out);
  mqttClient.publish(statusTopic.c_str(), out.c_str());
}

void handleCommandJson(String jsonStr) {
  StaticJsonDocument<384> doc;
  DeserializationError error = deserializeJson(doc, jsonStr);
  if (error) return;

  if (doc.containsKey("voltage")) applyVoltage(doc["voltage"]);

  if (doc.containsKey("ledMode") || doc.containsKey("speed") || doc.containsKey("brightness") ||
      doc.containsKey("color") || doc.containsKey("direction") || doc.containsKey("customStyle")) {
    String mode = doc.containsKey("ledMode") ? String((const char*)doc["ledMode"]) : "";
    int speed = doc.containsKey("speed") ? (int)doc["speed"] : -1;
    int brightness = doc.containsKey("brightness") ? (int)doc["brightness"] : -1;
    int direction = doc.containsKey("direction") ? (int)doc["direction"] : 0;
    String style = doc.containsKey("customStyle") ? String((const char*)doc["customStyle"]) : "";
    long colorVal = -1;
    if (doc.containsKey("color")) {
      String hex = String((const char*)doc["color"]);
      hex.replace("#", "");
      colorVal = strtol(hex.c_str(), (char**)NULL, 16);
    }
    applyLedSettings(mode, speed, brightness, colorVal, direction, style);
  }

  if (doc.containsKey("action") && String((const char*)doc["action"]) == "clear_cache") {
    applyVoltage(5.0);
    startMillis = millis();
  }

  publishStatus();
}

void handleRootConfig() {
  String html = "<html><head><meta name='viewport' content='width=device-width'><title>ESP32 Setup</title>"
                "<style>body{background:#0b0e14;color:#fff;font-family:sans-serif;text-align:center;padding:40px 20px;}"
                "input,button{padding:14px;width:80%;margin:10px;border-radius:12px;border:none;font-size:16px;}"
                "button{background:#00e5ff;color:#000;font-weight:bold;}</style></head>"
                "<body><h2>⚙️ WiFi Setup</h2><p style='opacity:.6;font-size:13px'>ID: " + deviceId + "</p><form action='/setwifi' method='GET'>"
                "<input name='ssid' placeholder='Nama WiFi' required><br>"
                "<input name='password' type='password' placeholder='Password' required><br>"
                "<button type='submit'>Simpan & Restart</button></form></body></html>";
  server.send(200, "text/html", html);
}

void handleSetWiFi() {
  if (server.hasArg("ssid") && server.hasArg("password")) {
    preferences.begin("wifi", false);
    preferences.putString("ssid", server.arg("ssid"));
    preferences.putString("pass", server.arg("password"));
    preferences.end();
    server.send(200, "text/plain", "OK");
    delay(1000);
    ESP.restart();
  } else {
    server.send(400, "text/plain", "Bad Request");
  }
}

void handleDeviceInfo() {
  StaticJsonDocument<128> doc;
  doc["deviceId"] = deviceId;
  doc["bleName"] = bleName;
  String jsonStr;
  serializeJson(doc, jsonStr);
  server.send(200, "application/json", jsonStr);
}

void handleSetVoltageHttp() {
  if (server.hasArg("voltage")) {
    applyVoltage(server.arg("voltage").toFloat());
    publishStatus();
    server.send(200, "application/json", "{\"status\":\"ok\"}");
  } else {
    server.send(400, "text/plain", "Missing voltage");
  }
}

void handleSetLedHttp() {
  String mode = server.hasArg("mode") ? server.arg("mode") : "";
  int speed = server.hasArg("speed") ? server.arg("speed").toInt() : -1;
  int brightness = server.hasArg("brightness") ? server.arg("brightness").toInt() : -1;
  int direction = server.hasArg("direction") ? server.arg("direction").toInt() : 0;
  String style = server.hasArg("customStyle") ? server.arg("customStyle") : "";
  long colorVal = -1;
  if (server.hasArg("color")) {
    String hex = server.arg("color");
    hex.replace("#", "");
    colorVal = strtol(hex.c_str(), (char**)NULL, 16);
  }
  if (mode.length() == 0 && speed < 0 && brightness < 0 && colorVal < 0 && direction == 0 && style.length() == 0) {
    server.send(400, "text/plain", "Missing parameters");
    return;
  }
  applyLedSettings(mode, speed, brightness, colorVal, direction, style);
  publishStatus();
  server.send(200, "application/json", "{\"status\":\"ok\"}");
}

void setup() {
  Serial.begin(115200);
  delay(800);

  deviceId = computeDeviceId();
  bleName = "ESP32-Cooler-" + deviceId;

  applyVoltage(5.0);
  strip.begin();
  loadLedPrefs();
  strip.setBrightness(map(ledBrightPct, 0, 100, 0, 255));
  strip.show();
  renderStaticFrame();

  loadWifiCreds();

  WiFi.mode(WIFI_AP_STA);
  WiFi.softAP(ap_ssid, ap_password);
  delay(300);
  if (wifiCredsExist) connectWifiSTA(true);

  cmdTopic = "cooler/" + deviceId + "/command";
  statusTopic = "cooler/" + deviceId + "/status";
  mqttClient.setServer(mqttBroker, mqttPort);
  mqttClient.setCallback(mqttMessageReceived);
  mqttClient.setBufferSize(512);
  reconnectMqttIfNeeded();

  server.on("/", handleRootConfig);
  server.on("/setwifi", handleSetWiFi);
  server.on("/api/set", handleSetVoltageHttp);
  server.on("/api/led", handleSetLedHttp);
  server.on("/api/info", handleDeviceInfo);
  server.begin();
  delay(300);

  BLEDevice::init(bleName.c_str());
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService *pService = pServer->createService(SERVICE_UUID);
  pCharacteristic = pService->createCharacteristic(
    CHARACTERISTIC_UUID,
    BLECharacteristic::PROPERTY_READ |
    BLECharacteristic::PROPERTY_WRITE |
    BLECharacteristic::PROPERTY_NOTIFY
  );

  pCharacteristic->addDescriptor(new BLE2902());
  pCharacteristic->setCallbacks(new MyCharacteristicCallbacks());
  pService->start();

  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);
  pAdvertising->setMaxPreferred(0x12);
  pServer->getAdvertising()->start();

  startMillis = millis();
  Serial.println("Inisialisasi Selesai, Sistem Berjalan Stabil!");
}

void loop() {

  if (bleDataReceived) {
    bleDataReceived = false;
    if (bleCommand.length() > 0) {
      handleCommandJson(bleCommand);
      bleCommand = "";
    }
  }

  if (wifiCredsExist && WiFi.status() != WL_CONNECTED && millis() - lastWifiRetry > WIFI_RETRY_INTERVAL) {
    lastWifiRetry = millis();
    connectWifiSTA(false);
  }

  reconnectMqttIfNeeded();
  mqttClient.loop();

  if (millis() - lastStatusPublish > STATUS_PUBLISH_INTERVAL) {
    lastStatusPublish = millis();
    publishStatus();
  }

  server.handleClient();
  handleLedAnimation();

  delay(5);
}
