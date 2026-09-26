"""
============================================================================
OzikSeal Backend — FPGA Serial Communication Service
============================================================================
Module: fpga_serial.py
Purpose: Handles UART communication with the DE10-Nano FPGA board.
         Provides a graceful fallback to software-based SHA-256 simulation
         when the physical hardware is not connected.

Architecture:
    ┌─────────────┐    UART (115200 baud)    ┌──────────────────┐
    │  This Module │ ──────────────────────► │  DE10-Nano FPGA  │
    │  (PySerial)  │ ◄────────────────────── │  SHA-256 Core    │
    └─────────────┘     64-char hex hash     └──────────────────┘

Author: OzikSeal Team
============================================================================
"""

import hashlib
import json
import logging
import time
from typing import Optional

import serial
from serial import SerialException

# ---------------------------------------------------------------------------
# Module Logger
# ---------------------------------------------------------------------------
logger = logging.getLogger("ozikseal.fpga_serial")


# ===========================================================================
# Configuration Constants
# ===========================================================================

# DE10-Nano UART Configuration
SERIAL_PORT_LINUX = "/dev/ttyUSB0"       # Linux default for USB-UART bridge
SERIAL_PORT_WINDOWS = "COM3"             # Windows default (adjust as needed)
BAUD_RATE = 115200                       # Must match FPGA UART module config
SERIAL_TIMEOUT = 5                       # Seconds to wait for FPGA response
HASH_LENGTH = 64                         # SHA-256 produces 64 hex characters


# ===========================================================================
# FPGA Serial Service Class
# ===========================================================================

class FPGASerialService:
    """
    Service class that manages serial communication with the DE10-Nano FPGA.

    This class encapsulates all UART logic and provides two operating modes:

    1. **Hardware Mode**: Sends data to the physical FPGA via UART and reads
       back the SHA-256 hash computed in silicon by the TT07 core.

    2. **Simulation Mode**: Automatically activated when the FPGA board is
       not connected. Uses Python's `hashlib.sha256` to generate an identical
       hash, ensuring the frontend demo works seamlessly without hardware.

    Usage:
        service = FPGASerialService()
        result = service.compute_hash(payload_dict)
    """

    def __init__(self, port: Optional[str] = None):
        """
        Initialize the FPGA serial service.

        Args:
            port: Serial port path. If None, attempts auto-detection
                  using common port paths for Linux and Windows.
        """
        self._port = port
        self._connection: Optional[serial.Serial] = None
        self._is_hardware_mode: bool = False

        # Attempt to establish hardware connection on init
        self._try_connect()

    # -----------------------------------------------------------------------
    # Connection Management
    # -----------------------------------------------------------------------

    def _try_connect(self) -> None:
        """
        Attempt to open a serial connection to the DE10-Nano FPGA.

        Tries the specified port first, then falls back to common defaults.
        If all attempts fail, the service silently switches to Simulation Mode.
        """
        ports_to_try = []

        if self._port:
            ports_to_try.append(self._port)
        else:
            # Try common port paths for both operating systems
            ports_to_try.extend([
                SERIAL_PORT_LINUX,
                SERIAL_PORT_WINDOWS,
                "/dev/ttyACM0",   # Alternative Linux USB-ACM device
                "COM4",           # Alternative Windows COM port
            ])

        for port in ports_to_try:
            try:
                self._connection = serial.Serial(
                    port=port,
                    baudrate=BAUD_RATE,
                    bytesize=serial.EIGHTBITS,
                    parity=serial.PARITY_NONE,
                    stopbits=serial.STOPBITS_ONE,
                    timeout=SERIAL_TIMEOUT,
                )
                self._is_hardware_mode = True
                logger.info(
                    f"✅ HARDWARE MODE — Connected to DE10-Nano on {port} "
                    f"@ {BAUD_RATE} baud"
                )
                return

            except SerialException:
                logger.debug(f"Port {port} not available, trying next...")
                continue

        # All ports failed — switch to simulation
        self._is_hardware_mode = False
        logger.warning(
            "⚠️  SIMULATION MODE — No FPGA board detected. "
            "Using software SHA-256 fallback."
        )

    @property
    def is_hardware_mode(self) -> bool:
        """Returns True if communicating with a physical FPGA board."""
        return self._is_hardware_mode

    @property
    def mode_label(self) -> str:
        """Human-readable label for the current operating mode."""
        return "hardware" if self._is_hardware_mode else "simulation"

    # -----------------------------------------------------------------------
    # Core Hash Computation
    # -----------------------------------------------------------------------

    def compute_hash(self, payload: dict) -> str:
        """
        Compute the SHA-256 hash of a claim payload.

        This is the primary interface method. It automatically routes to
        either hardware or software computation based on connection status.

        Args:
            payload: Dictionary containing claim data (patient_id, drug, etc.)

        Returns:
            A 64-character lowercase hexadecimal SHA-256 hash string.

        Raises:
            RuntimeError: If hardware communication fails unexpectedly.
        """
        # Serialize payload to a canonical JSON string (sorted keys for
        # deterministic hashing across different systems)
        payload_json = json.dumps(payload, sort_keys=True, separators=(",", ":"))

        if self._is_hardware_mode:
            return self._compute_via_hardware(payload_json)
        else:
            return self._compute_via_software(payload_json)

    def _compute_via_hardware(self, data: str) -> str:
        """
        Send data to the FPGA over UART and read back the SHA-256 hash.

        Protocol:
            1. Transmit the UTF-8 encoded payload bytes to the FPGA.
            2. Send a newline character (0x0A) as an end-of-message delimiter.
            3. Read back exactly 64 hex characters (the SHA-256 digest).

        Args:
            data: The canonical JSON string to hash.

        Returns:
            64-character hex hash string from the FPGA.

        Raises:
            RuntimeError: If the FPGA response is invalid or timed out.
        """
        try:
            logger.info(f"📡 Transmitting {len(data)} bytes to FPGA...")

            # Flush any stale data in the serial buffers
            self._connection.reset_input_buffer()
            self._connection.reset_output_buffer()

            # Transmit payload + newline delimiter
            self._connection.write(data.encode("utf-8"))
            self._connection.write(b"\n")
            self._connection.flush()

            # Read the response (64 hex chars + newline)
            response_raw = self._connection.readline()
            response = response_raw.decode("utf-8").strip()

            # Validate response format
            if len(response) != HASH_LENGTH:
                raise RuntimeError(
                    f"Invalid FPGA response length: expected {HASH_LENGTH}, "
                    f"got {len(response)}. Raw: '{response}'"
                )

            logger.info(f"✅ FPGA returned hash: {response[:16]}...")
            return response.lower()

        except (SerialException, OSError) as e:
            logger.error(f"❌ Hardware communication failed: {e}")
            logger.warning("Falling back to simulation mode for this request.")
            return self._compute_via_software(data)

    def _compute_via_software(self, data: str) -> str:
        """
        Compute SHA-256 hash using Python's hashlib (simulation fallback).

        This produces an identical result to what the FPGA hardware would
        generate, ensuring consistent behavior across modes.

        Args:
            data: The canonical JSON string to hash.

        Returns:
            64-character hex hash string.
        """
        # Add a small delay to simulate hardware processing time
        # This makes the demo feel more realistic
        time.sleep(0.3)

        hash_result = hashlib.sha256(data.encode("utf-8")).hexdigest()
        logger.info(f"🖥️  Software SHA-256: {hash_result[:16]}...")
        return hash_result

    # -----------------------------------------------------------------------
    # Cleanup
    # -----------------------------------------------------------------------

    def close(self) -> None:
        """Safely close the serial connection to the FPGA."""
        if self._connection and self._connection.is_open:
            self._connection.close()
            logger.info("Serial connection closed.")

    def __del__(self):
        """Destructor — ensures serial port is released."""
        self.close()
