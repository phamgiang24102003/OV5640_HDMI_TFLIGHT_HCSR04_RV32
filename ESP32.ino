#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>

const char *ssid     = "Giang";
const char *password = "88888888";

String uploadUrl = "https://polypoid-joette-chromophoric.ngrok-free.dev/upload_block";

#define UART_BAUD   460800
#define RX_PIN      16
#define TX_PIN      17

#define CMD_REQ_BLOCK  0xFF
#define CMD_FPGA_READY 0x0F
#define CMD_ESP_ACK    0xF0
#define CMD_FRAME_DONE 0xEE

#define BLOCK_SIZE  51200
#define FRAME_SIZE  (320 * 240 * 2)
#define BLOCKS_PER_FRAME ((FRAME_SIZE + BLOCK_SIZE - 1) / BLOCK_SIZE)

uint8_t *block = NULL;
int current_block = 0;
int total_bytes_received = 0;
bool frame_done_received = false;

void setupUART() {
    Serial2.setRxBufferSize(32768); 
    Serial2.begin(UART_BAUD, SERIAL_8N1, RX_PIN, TX_PIN);
}

bool uploadBlock(uint8_t *data, int len) {
    WiFiClientSecure client;
    client.setInsecure();
    HTTPClient http;
    http.setTimeout(30000); 
    
    if (!http.begin(client, uploadUrl)) return false;
    
    http.addHeader("Content-Type", "application/octet-stream");
    http.addHeader("X-Block-Number", String(current_block));
    http.addHeader("X-Block-Size", String(len));
    http.addHeader("ngrok-skip-browser-warning", "true");

    int code = http.POST(data, len);
    http.end();
    return (code == 200);
}

void clearBuffer() {
    while(Serial2.available()) Serial2.read();
}

void setup() {
    Serial.begin(115200);
    
    if (psramInit()) {
        block = (uint8_t*) ps_malloc(BLOCK_SIZE + 1);
        Serial.println("PSRAM initialized successfully.");
    } else {
        block = (uint8_t*) malloc(BLOCK_SIZE + 1);
        Serial.println("PSRAM not found. Using internal RAM.");
    }

    if (!block) { 
        Serial.println("Memory allocation failed!"); 
        while(1); 
    }

    WiFi.begin(ssid, password);
    Serial.print("Connecting to WiFi");
    while (WiFi.status() != WL_CONNECTED) {
        delay(100);
        Serial.print(".");
    }
    Serial.println("\nWiFi Connected!");
    Serial.printf("IP Address: %s\n", WiFi.localIP().toString().c_str());

    setupUART();
    
    Serial.println("System Ready. Waiting for FPGA...");
    Serial.printf("Frame size: %d bytes | Block size: %d bytes\n", FRAME_SIZE, BLOCK_SIZE);
}

void loop() {
    if (current_block == 0) {
         Serial.println("\n--- Waiting for New Frame (Block 1) ---");
    } else {
         Serial.printf("\n--- Requesting Block %d ---\n", current_block + 1);
    }

    // ============================================
    // STEP 1: HANDSHAKE WITH FPGA
    // ============================================
    
    clearBuffer();
    
    // Send Request Command (0xFF)
    Serial2.write(CMD_REQ_BLOCK); 
    Serial2.flush();
    
    // Wait for Ready Response (0x0F)
    unsigned long waitStart = millis();
    bool fpgaReady = false;
    
    int timeout_ms = (current_block == 0) ? 1000 : 3000;

    while (millis() - waitStart < timeout_ms) {
        if (Serial2.available()) {
            uint8_t response = Serial2.read();
            if (response == CMD_FPGA_READY) {
                fpgaReady = true;
                if(current_block == 0) Serial.println("FPGA Ready! Starting new frame.");
                else Serial.println("FPGA Handshake OK.");
                break;
            } else if (response == CMD_FRAME_DONE) {
                Serial.println("CMD_FRAME_DONE received during handshake.");
                frame_done_received = true;
                return; // Restart loop to handle completion
            }
        }
    }

    if (!fpgaReady) {
        if (current_block == 0) {
            delay(1000); 
            return;
        } else {
            Serial.println("FPGA timeout within frame. Retrying...");
            delay(500);
            return;
        }
    }

    // Send ACK (0xF0)
    Serial2.write(CMD_ESP_ACK);
    Serial2.flush();

    // ============================================
    // STEP 2: RECEIVE DATA FROM FPGA
    // ============================================
    
    int remaining_in_frame = FRAME_SIZE - total_bytes_received;
    int expected_bytes = min(BLOCK_SIZE, remaining_in_frame);
    
    int bytesRead = 0;
    unsigned long readStart = millis();
    unsigned long lastByteTime = millis();
    
    while (bytesRead < expected_bytes) {
        if (Serial2.available()) {
            int avail = Serial2.available();
            int toRead = min(avail, expected_bytes - bytesRead);
            int actualRead = Serial2.readBytes(block + bytesRead, toRead);
            bytesRead += actualRead;
            lastByteTime = millis();
        }
        
        if (millis() - lastByteTime > 2000) {
            Serial.println("Timeout: No data received for 2 seconds.");
            break;
        }
        
        if (millis() - readStart > 10000) {
            Serial.println("Critical timeout: Overall block read time exceeded.");
            break;
        }
    }

    Serial.printf("Block %d: Received %d/%d bytes\n", current_block + 1, bytesRead, expected_bytes);

    if (bytesRead != expected_bytes) {
        Serial.printf("UART Error: Incomplete read (%d/%d). Retrying block...\n", bytesRead, expected_bytes);
        delay(1000);
        return;
    }

    total_bytes_received += bytesRead;

    // ============================================
    // STEP 3: CHECK FOR FRAME_DONE SIGNAL
    // ============================================
    delay(10);
    if (Serial2.available()) {
        uint8_t cmd = Serial2.read();
        if (cmd == CMD_FRAME_DONE) {
            Serial.println("CMD_FRAME_DONE (0xEE) signal received.");
            frame_done_received = true;
        }
    }

    // ============================================
    // STEP 4: UPLOAD BLOCK TO SERVER
    // ============================================
    
    int retryCount = 0;
    bool uploadSuccess = false;
    while (!uploadSuccess && retryCount < 5) {
        if (uploadBlock(block, bytesRead)) {
            uploadSuccess = true;
        } else {
            retryCount++;
            Serial.printf("Upload failed. Retry %d/5...\n", retryCount);
            delay(1000);
        }
    }

    if (!uploadSuccess) {
        Serial.println("Upload failed after maximum retries. Resetting frame...");
        current_block = 0;
        total_bytes_received = 0;
        frame_done_received = false;
        return;
    }

    // ============================================
    // STEP 5: PROCESS NEXT BLOCK OR FINALIZE
    // ============================================
    
    current_block++;
    
    if (total_bytes_received >= FRAME_SIZE || frame_done_received) {
        Serial.println("\n========================================");
        Serial.println("      FRAME TRANSMISSION COMPLETE!      ");
        Serial.println("========================================");
        
        if (!frame_done_received) {
             unsigned long stopWait = millis();
             while(millis() - stopWait < 500) { 
                 if (Serial2.available()) {
                     if (Serial2.read() == CMD_FRAME_DONE) break;
                 }
             }
        }

        Serial.println("Ready for the next frame. Resetting counters...");
        
        current_block = 0;
        total_bytes_received = 0;
        frame_done_received = false;
        
        delay(2000); 
    }
}