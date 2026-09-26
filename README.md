# 🛡️ OzikSeal: Hardware-Accelerated Digital Trust
> **A Zero-Trust, Hardware-Level Cryptographic Escrow & Anti-Fraud Architecture for National Health Insurance (JKN) Claims.**

---

## 🚀 Overview
**OzikSeal** is an enterprise-grade infrastructure designed to eliminate systemic financial leakage (such as *Phantom Billing*, *Repeat Billing*, and *Upcoding*) in large-scale healthcare ecosystems like BPJS Kesehatan. 

While conventional systems rely purely on vulnerable software layers, OzikSeal bridges high-level web interfaces with a dedicated physical **FPGA (DE10-Nano)** hardware accelerator. By offloading sensitive cryptographic hashing (**SHA-256**) directly into isolated silicon logic cores, OzikSeal creates a tamper-proof audit trail that is physically immune to remote software tampering or insider manipulation.

---

## 🏗️ System Architecture (Hardware/Software Partitioning)

The architecture is strictly decoupled into three modular pillars to ensure optimal performance, security, and maintainability:

```text
+-----------------------+       UART / USB       +---------------------------+
|  Frontend (Next.js)   | <--------------------> |  Backend (Python FastAPI) |
|  - Pharmacy POS UI    |                        |  - Serial Bridge Service  |
+-----------------------+                        +---------------------------+
                                                               |
                                                               v  (Raw Payload)
                                                 +---------------------------+
                                                 | Hardware FPGA (DE10-Nano) |
                                                 | - UART RX/TX Modules      |
                                                 | - Peruri TT07 SHA-256 Core|
                                                 +---------------------------+
```

### How It Works
1. **Pharmacist** enters a BPJS/JKN claim in the frontend POS interface.
2. Frontend sends a `POST /api/secure-claim` request to the backend.
3. Backend serializes the claim into a JSON payload and transmits it via **UART** to the physical **DE10-Nano FPGA board**.
4. The FPGA's **SHA-256 hardware core** (TT07 baseline) computes the cryptographic hash entirely in silicon — no software, no CPU.
5. The hash is returned via UART to the backend, which responds to the frontend.
6. Frontend displays the tamper-proof digital seal with verification status.

> **Fallback:** If no FPGA board is connected, the backend gracefully falls back to
> **Simulation Mode** using Python's `hashlib.sha256`, so the demo always works.

---

## Directory Structure

```
/ozikseal-jkn-accelerator
├── README.md                          # You are here
├── /frontend                          # Next.js + Tailwind CSS Dashboard
│   ├── package.json
│   ├── next.config.mjs
│   ├── tailwind.config.js
│   ├── postcss.config.mjs
│   └── /src
│       ├── /app
│       │   ├── layout.js              # Root layout with fonts & metadata
│       │   ├── page.js                # Main dashboard page
│       │   └── globals.css            # Tailwind directives + custom styles
│       └── /components
│           ├── ClaimForm.jsx           # Left panel: Pharmacy POS form
│           └── FPGAMonitor.jsx         # Right panel: Hardware terminal
│
├── /backend                           # Python FastAPI + PySerial Bridge
│   ├── requirements.txt
│   ├── main.py                        # FastAPI app entry point
│   └── fpga_serial.py                 # UART communication service
│
└── /hardware                          # Verilog RTL + Quartus Project
    ├── /rtl
    │   ├── OzikSeal_Top.v             # Top-level FPGA wrapper
    │   ├── uart_rx.v                  # UART receiver module
    │   └── uart_tx.v                  # UART transmitter module
    ├── /testbench
    │   └── tb_ozikseal.v              # Simulation testbench for GTKWave
    └── /quartus
        └── ozikseal_de10nano.qsf      # Quartus pin assignment file
```

---

## Quick Start

### Prerequisites
- **Node.js** >= 18.x
- **Python** >= 3.10
- **Intel Quartus Prime Lite** (for FPGA synthesis — optional for demo)

### 1. Backend Setup
```bash
cd backend
python -m venv venv
source venv/bin/activate        # On Windows: venv\Scripts\activate
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
```

### 2. Frontend Setup
```bash
cd frontend
npm install
npm run dev
# → Opens at http://localhost:3000
```

### 3. Hardware (Optional — Synthesis)
```bash
# Open Intel Quartus Prime
# File → Open Project → hardware/quartus/ozikseal_de10nano.qsf
# Run: Analysis & Synthesis → Fitter → Assembler
# Program the DE10-Nano via USB-Blaster
```

### 4. Hardware (Simulation with Icarus Verilog)
```bash
cd hardware
iverilog -o sim.vvp testbench/tb_ozikseal.v rtl/OzikSeal_Top.v rtl/uart_rx.v rtl/uart_tx.v
vvp sim.vvp
gtkwave ozikseal_wave.vcd
```

---

## API Reference

### `POST /api/secure-claim`
Accepts a pharmacy claim payload and returns a hardware-sealed SHA-256 hash.

**Request Body:**
```json
{
  "patient_id": "JKN-2026-9821",
  "drug_name": "Amoxicillin 500mg",
  "claim_amount": 150000,
  "auth_pin": "821994"
}
```

**Response (200 OK):**
```json
{
  "status": "success",
  "mode": "hardware",
  "payload": { ... },
  "sha256_hash": "8d969eef6ecad3c29a3a629280e686cf...",
  "timestamp": "2026-09-26T12:00:00.000Z",
  "device": "DE10-Nano (Cyclone V)"
}
```

---

## Tech Stack

| Layer     | Technology                    | Purpose                              |
|-----------|-------------------------------|--------------------------------------|
| Frontend  | Next.js 15, Tailwind CSS 3    | Minimalist POS Dashboard             |
| Backend   | Python 3, FastAPI, PySerial   | API Gateway & UART Bridge            |
| Hardware  | Verilog HDL, Intel Quartus    | SHA-256 Crypto Core on FPGA Silicon  |
| Board     | Intel DE10-Nano (Cyclone V)   | Physical FPGA Target Platform        |

---

## License
MIT — Built for the OzikSeal Hackathon Demo.
