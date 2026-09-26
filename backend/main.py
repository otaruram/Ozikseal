"""
============================================================================
OzikSeal Backend — FastAPI Application Entry Point
============================================================================
Module: main.py
Purpose: Exposes the REST API that bridges the frontend POS dashboard
         with the FPGA hardware cryptographic accelerator.

Endpoints:
    POST /api/secure-claim  →  Accept claim data, hash via FPGA, return seal
    GET  /api/health        →  System health check & mode detection

Run:
    uvicorn main:app --reload --port 8000

Author: OzikSeal Team
============================================================================
"""

import logging
from datetime import datetime, timezone

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from fpga_serial import FPGASerialService

# ---------------------------------------------------------------------------
# Logging Configuration
# ---------------------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s │ %(name)-28s │ %(levelname)-7s │ %(message)s",
    datefmt="%H:%M:%S",
)
logger = logging.getLogger("ozikseal.api")


# ===========================================================================
# Pydantic Models — Request & Response Schemas
# ===========================================================================

class ClaimRequest(BaseModel):
    """
    Incoming pharmacy claim data from the frontend POS.

    All fields are required. The `auth_pin` is never stored or logged
    in plaintext — it is only used as part of the hash input to bind
    the claim to the patient's authentication.
    """
    patient_id: str = Field(
        ...,
        description="Unique BPJS/JKN patient identifier",
        examples=["JKN-2026-9821"],
    )
    drug_name: str = Field(
        ...,
        description="Name and dosage of the prescribed drug",
        examples=["Amoxicillin 500mg"],
    )
    claim_amount: int = Field(
        ...,
        description="Claim amount in IDR (Indonesian Rupiah)",
        examples=[150000],
        gt=0,
    )
    auth_pin: str = Field(
        ...,
        description="6-digit patient authentication PIN",
        examples=["821994"],
        min_length=1,
        max_length=6,
    )


class ClaimResponse(BaseModel):
    """
    Response returned after the claim has been cryptographically sealed.

    Contains the original payload, the SHA-256 hash, the operating mode
    (hardware vs. simulation), and a UTC timestamp.
    """
    status: str = Field(
        ...,
        description="Processing result status",
        examples=["success"],
    )
    mode: str = Field(
        ...,
        description="'hardware' if FPGA was used, 'simulation' if fallback",
        examples=["hardware", "simulation"],
    )
    payload: dict = Field(
        ...,
        description="The original claim data that was hashed",
    )
    sha256_hash: str = Field(
        ...,
        description="64-character SHA-256 hex digest from the FPGA/simulation",
    )
    timestamp: str = Field(
        ...,
        description="ISO 8601 UTC timestamp of when the seal was created",
    )
    device: str = Field(
        ...,
        description="Identifier of the hardware device used",
        examples=["DE10-Nano (Cyclone V)"],
    )


class HealthResponse(BaseModel):
    """Health check response showing system status and FPGA mode."""
    status: str
    mode: str
    device: str
    uptime: str


# ===========================================================================
# Application Initialization
# ===========================================================================

app = FastAPI(
    title="OzikSeal API",
    description=(
        "Hardware-Accelerated Digital Trust API for BPJS/JKN Healthcare Claims. "
        "Bridges the pharmacy POS frontend with the DE10-Nano FPGA SHA-256 core."
    ),
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

# ---------------------------------------------------------------------------
# CORS Configuration — Allow frontend to communicate with the API
# ---------------------------------------------------------------------------
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",      # Next.js dev server
        "http://localhost:5173",      # Vite dev server (if used)
        "http://127.0.0.1:3000",
        "http://127.0.0.1:5173",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------------------------------------------------------------------------
# Initialize FPGA Service (Singleton — created once at startup)
# ---------------------------------------------------------------------------
fpga_service = FPGASerialService()


# ===========================================================================
# API Endpoints
# ===========================================================================

@app.post(
    "/api/secure-claim",
    response_model=ClaimResponse,
    summary="Seal a pharmacy claim with hardware SHA-256",
    tags=["Claims"],
)
async def secure_claim(claim: ClaimRequest) -> ClaimResponse:
    """
    Accept a pharmacy claim, compute its SHA-256 hash via the FPGA
    hardware accelerator, and return the tamper-proof digital seal.

    **Processing Flow:**
    1. Validate the incoming claim data (Pydantic handles this).
    2. Build a canonical payload dictionary.
    3. Send to `FPGASerialService.compute_hash()` which routes to
       either hardware (UART) or software (hashlib) automatically.
    4. Return the signed response with hash and metadata.

    **Error Handling:**
    - If the FPGA is not connected, the system automatically falls back
      to simulation mode — the frontend will never see an error.
    - If the claim data is malformed, a 422 Unprocessable Entity is returned.
    """
    try:
        # Build the payload to be hashed
        # Note: auth_pin is included in the hash but masked in the response
        payload = {
            "patient_id": claim.patient_id,
            "drug_name": claim.drug_name,
            "claim_amount": claim.claim_amount,
            "auth_pin": claim.auth_pin,
        }

        logger.info(
            f"📋 Processing claim for patient {claim.patient_id} | "
            f"Drug: {claim.drug_name} | Amount: Rp {claim.claim_amount:,}"
        )

        # Compute SHA-256 hash (hardware or simulation)
        sha256_hash = fpga_service.compute_hash(payload)

        # Build the response payload (mask the PIN for security)
        response_payload = {
            "patient_id": claim.patient_id,
            "drug_name": claim.drug_name,
            "claim_amount": claim.claim_amount,
            "auth_pin": "***",  # Never expose the PIN in responses
        }

        logger.info(
            f"✅ Claim sealed | Mode: {fpga_service.mode_label} | "
            f"Hash: {sha256_hash[:16]}..."
        )

        return ClaimResponse(
            status="success",
            mode=fpga_service.mode_label,
            payload=response_payload,
            sha256_hash=sha256_hash,
            timestamp=datetime.now(timezone.utc).isoformat(),
            device="DE10-Nano (Cyclone V)",
        )

    except Exception as e:
        logger.error(f"❌ Failed to process claim: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Internal error while processing claim: {str(e)}",
        )


@app.get(
    "/api/health",
    response_model=HealthResponse,
    summary="System health check",
    tags=["System"],
)
async def health_check() -> HealthResponse:
    """
    Returns the current system status, including whether the FPGA
    hardware is connected or running in simulation mode.
    """
    return HealthResponse(
        status="online",
        mode=fpga_service.mode_label,
        device="DE10-Nano (Cyclone V)" if fpga_service.is_hardware_mode else "Software Simulation",
        uptime="active",
    )


# ===========================================================================
# Startup & Shutdown Events
# ===========================================================================

@app.on_event("startup")
async def on_startup():
    """Log system status on application startup."""
    logger.info("=" * 60)
    logger.info("  OzikSeal API — Starting Up")
    logger.info(f"  Mode: {fpga_service.mode_label.upper()}")
    logger.info(f"  FPGA Connected: {fpga_service.is_hardware_mode}")
    logger.info("=" * 60)


@app.on_event("shutdown")
async def on_shutdown():
    """Clean up serial connections on shutdown."""
    fpga_service.close()
    logger.info("OzikSeal API — Shut down cleanly.")
