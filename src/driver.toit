import gpio
import spi

MAX_BUS_SPEED ::= 2_000_000

class Driver:
  device_    /spi.Device
  registers_ /spi.Registers
  
  // Register addresses
  static OFFSET_ ::= 0
  static GAIN_   ::= 1
  static CONFIG_ ::= 2
  static CONVERSION_ ::= 3

  // Commands
  static PERFORM_SINGLE_CONVERSION  ::= 192  // 0xC0
  static PERFORM_CONTINUOUS_CONVERSION ::= 160  // 0xA0
  static POWER_SAVE ::= 129  // 0x81
  static RUN ::= 128  // 0x80
  static NULL ::= 0  //0x00

  constructor .device_/spi.Device:
    registers_ = device_.registers
    registers_.set-msb-write true  // Ensure MSB write mode
    sleep --ms=500  // Wait for external oscillator to stabilize
    initialize

  read-register_ register/int -> int:
    // The CS5529_F5 only seems to have 5 registers.  
    assert: 0 <= register <= 4
    device_.with-reserved-bus:
      read-command := 0b1001_0000 | (register << 1)
      device_.write #[read-command] --keep-cs-active
      bytes := device_.read 3
      return (bytes[0] << 16) | (bytes[1] << 8) | bytes[2]
    unreachable

  write-register_ register/int data/ByteArray:
    // The CS5529_F5 only seems to have 5 registers.  
    assert: 0 <= register <= 4
    device_.with-reserved-bus:
      write-command := 0b1000_0000 | (register << 1)
      device_.write #[write-command] --keep-cs-active
      device_.write data
      
  send-command_ command/int -> none:
    device_.write #[command]

  // Serial Port Synchronization
  sync:
    sync_bytes := ByteArray 17
    sync_bytes.fill 0xFF
    sync_bytes[16] = 0xFE  // Final SYNC0 command
    device_.write sync_bytes

  // Initialize CS5529 with external clock
  initialize:
    sync

    sleep --ms=1
    print (read-register_ CONFIG_)

    // set reset state
    write-register_ CONFIG_ #[0x00, 0x00, 0x80]
    sleep --ms=1
    // read config
    print (read-register_ 2)
    // clear reset
    write-register_ 2 #[0x00, 0x00, 0x00]
    sleep --ms=1

    configure-adc

  // Configure ADC (e.g., word rate, mode)
  configure-adc:
    device_.with-reserved-bus:
      send-command_ PERFORM-SINGLE-CONVERSION
      sleep --ms=100
      send-command_ NULL
  
  check-ready:
    return read-register_ CONFIG_
  
  read-adc:
    return read-register_ CONVERSION_


