import cs5529
import spi

main:
  bus := spi.Bus
    --mosi=gpio.Pin 21
    --miso=gpio.Pin 19
    --clock=gpio.Pin 18
    
  device := bus.device 
    --cs=gpio.Pin 5
    --frequency=cs5529.MAX-BUS-FREQUENCY

  adc := cs5529 device
