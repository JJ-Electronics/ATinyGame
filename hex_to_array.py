#!/usr/bin/env python3
import sys

def hex_to_c_array(hex_file_path):
    try:
        with open(hex_file_path, 'r') as hex_file:
            print("const uint8_t hardcodedProgramData[] PROGMEM = {")
            for line in hex_file:
                # Skip lines that don't start with ':'
                if not line.startswith(':'):
                    continue
                
                byte_count = int(line[1:3], 16)
                address = line[3:7]
                record_type = int(line[7:9], 16)
                data = line[9:9 + 2 * byte_count]
                checksum = line[9 + 2 * byte_count:11 + 2 * byte_count]

                # Skip non-data records
                if record_type != 0x00:
                    continue

                # Process data bytes
                for i in range(0, len(data), 2):
                    byte = data[i:i+2]
                    print(f"  0x{byte}, ", end='')

                print() # New line for the next data line
            
            print("};")
            print("const int hardcodedProgramSize = sizeof(hardcodedProgramData);")
    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python hex_to_c_array.py <hex_file_path>")
    else:
        hex_file_path = sys.argv[1]
        hex_to_c_array(hex_file_path)

