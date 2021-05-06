import time
import serial

# configure the serial port
ser = serial.Serial(
    port='COM3', # Change as needed
    baudrate=115200,
    parity=serial.PARITY_NONE,
    stopbits=serial.STOPBITS_TWO,
    bytesize=serial.EIGHTBITS
)
ser.isOpen()

while 1 :
    strin = ser.readline()
    print (strin.decode('utf-8'))
