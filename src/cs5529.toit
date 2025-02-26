import gpio
import spi

/**
Driver for the CS5529 ADC.

The CS5529 is a 16-bit ADC with a 4-channel multiplexer.
See https://www.cirrus.com/products/cs5529/.
*/

MAX-BUS-SPEED ::= 2_000_000

/**
Driver for the CS5529 ADC.
*/
class Cs5529:
  device_    /spi.Device
  registers_ /spi.Registers

  // Register addresses.
  // Table 1, page 12, D3-D1.
  static OFFSET_     ::= 0b000
  static GAIN_       ::= 0b001
  static CONFIG_     ::= 0b010
  static CONVERSION_ ::= 0b011

  // Configuration flags.
  static CONFIG-DONE-FLAG-BIT_ ::= 0x08

  // Commands.
  static PERFORM-SINGLE-CONVERSION_ ::= 0xC0
  static PERFORM-CONTINUOUS-CONVERSION_ ::= 0xA0
  static POWER-SAVE_ ::= 0x81
  static RUN_ ::= 0x80
  static NULL_ ::= 0x00

  constructor .device_/spi.Device:
    registers_ = device_.registers
    registers_.set-msb-write true  // Ensure MSB write mode.
    // Most people probably use the internal oscillator, and the given
    // start-up time is for the internal oscillator. See footnote 21 on page 8.
    sleep --ms=500  // Wait for oscillator to stabilize.
    initialize_

  read-register_ register/int -> int:
    // The CS5529_F5 has 5 registers.
    assert: 0 <= register <= 4
    device_.with-reserved-bus:
      read-command := 0b1001_0000 | (register << 1)
      device_.write #[read-command] --keep-cs-active
      bytes := device_.read 3
      return (bytes[0] << 16) | (bytes[1] << 8) | bytes[2]
    unreachable

  write-register_ register/int data/ByteArray:
    // The CS5529_F5 has 5 registers.
    assert: 0 <= register <= 4
    device_.with-reserved-bus:
      write-command := 0b1000_0000 | (register << 1)
      device_.write #[write-command] --keep-cs-active
      device_.write data

  send-command_ command/int -> none:
    device_.write #[command]

  // Serial Port Synchronization
  sync_:
    sync-bytes := ByteArray 17: 0xFF
    sync-bytes[16] = 0xFE  // Final SYNC0 command.
    device_.write sync-bytes

  // Initialize CS5529.
  initialize_:
    sync_

    sleep --ms=10
    print (read-register_ CONFIG_)
    // Set reset state.
    write-register_ CONFIG_ #[0x00, 0x00, 0x80]
    sleep --ms=10
    // Read config.
    print (read-register_ 2)
    // Clear reset.
    write-register_ 2 #[0x00, 0x00, 0x00]
    sleep --ms=10
    write-register_ CONFIG_ #[0x00, 0xB0, 0x00]

  read --raw/True -> int:
    // set to highest res
    // Start the conversion.
    send-command_ PERFORM-SINGLE-CONVERSION_
    sleep --ms=50

    // Once the conversion is done, the configuration's done flag is set.
    while true:  // You should probably add a timeout here.
      config := read-register_ CONFIG_
      if (config & CONFIG-DONE-FLAG-BIT_) != 0: break
      sleep --ms=10

    // Read it. This automatically clears the done flag.
    return read-register_ CONVERSION_

  read -> float:
    // Use the "Output coding" section on page 22 to convert the
    // raw value to a voltage.
    raw := read --raw
    return (raw >> 8) / 26.0
