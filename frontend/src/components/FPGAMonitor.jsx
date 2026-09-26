/**
 * ============================================================================
 * OzikSeal Frontend — FPGAMonitor Component
 * ============================================================================
 * Purpose: Right panel of the dashboard. Simulates a hardware terminal that
 *          displays the FPGA processing status and results.
 *
 * States:
 *   - "idle"    → "Waiting for incoming data stream..."
 *   - "loading" → Spinner + "Transmitting to DE10-Nano..."
 *   - "success" → Raw payload, SHA-256 hash, QR code, VERIFIED badge
 *   - "error"   → Error message display
 *
 * Props:
 *   - state: "idle" | "loading" | "success" | "error"
 *   - result: Object with { payload, sha256_hash, mode, timestamp } (for success)
 *   - error: Error message string (for error state)
 *
 * Design: Dark terminal aesthetic (black bg) with neon green accents.
 * ============================================================================
 */

"use client";

import { QRCodeSVG } from "qrcode.react";

// ===========================================================================
// Sub-Component: Loading Spinner
// ===========================================================================
function LoadingSpinner() {
  return (
    <svg
      className="animate-spin-smooth h-10 w-10 text-[var(--color-neon-green)]"
      xmlns="http://www.w3.org/2000/svg"
      fill="none"
      viewBox="0 0 24 24"
    >
      <circle
        className="opacity-25"
        cx="12"
        cy="12"
        r="10"
        stroke="currentColor"
        strokeWidth="4"
      />
      <path
        className="opacity-75"
        fill="currentColor"
        d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
      />
    </svg>
  );
}


// ===========================================================================
// Main FPGAMonitor Component
// ===========================================================================
export default function FPGAMonitor({ state = "idle", result = null, error = null }) {
  return (
    <section className="w-full md:w-1/2 p-8 lg:p-12 bg-black text-white flex flex-col">
      {/* Section Header */}
      <div className="mb-6">
        <h2 className="text-xl lg:text-2xl font-bold flex items-center gap-3 tracking-tight">
          <span>FPGA Chip Monitor</span>
          <span className="text-[10px] border border-gray-600 text-gray-400 px-2 py-0.5 rounded font-mono">
            TT07 SHA-256
          </span>
        </h2>
      </div>

      {/* Terminal Window */}
      <div className="flex-grow border border-[var(--color-terminal-border)] bg-[var(--color-terminal-bg)] p-5 font-mono text-sm overflow-hidden relative flex flex-col min-h-[400px]">

        {/* ─── IDLE STATE ─── */}
        {state === "idle" && (
          <div className="h-full flex items-center justify-center text-gray-600">
            <span className="animate-pulse">
              Waiting for incoming data stream...
              <span className="animate-cursor-blink ml-0.5">█</span>
            </span>
          </div>
        )}

        {/* ─── LOADING STATE ─── */}
        {state === "loading" && (
          <div className="h-full flex flex-col items-center justify-center space-y-4 text-[var(--color-neon-green)]">
            <LoadingSpinner />
            <div className="text-center space-y-1">
              <p className="text-sm font-semibold">Transmitting to DE10-Nano...</p>
              <p className="text-xs opacity-60">
                Processing cryptographic hash via Hardware Baseline...
              </p>
            </div>
          </div>
        )}

        {/* ─── SUCCESS STATE ─── */}
        {state === "success" && result && (
          <div className="flex flex-col h-full space-y-5 animate-fade-in-up">

            {/* Raw Payload */}
            <div>
              <h3 className="text-[10px] text-gray-500 mb-1.5 uppercase tracking-[0.2em] border-b border-gray-800 pb-1">
                Raw Payload Received
              </h3>
              <pre className="text-green-400 text-xs overflow-x-auto whitespace-pre-wrap leading-relaxed">
{JSON.stringify(result.payload, null, 2)}
              </pre>
            </div>

            {/* SHA-256 Hash */}
            <div>
              <h3 className="text-[10px] text-gray-500 mb-1.5 uppercase tracking-[0.2em] border-b border-gray-800 pb-1">
                Generated SHA-256 Hash
              </h3>
              <div className="animate-typewriter">
                <p className="break-all font-bold text-base lg:text-lg text-white tracking-tight leading-relaxed">
                  {result.sha256_hash}
                </p>
              </div>
            </div>

            {/* Mode Badge */}
            <div>
              <span className="text-[10px] px-2 py-0.5 border rounded font-mono" style={{
                borderColor: result.mode === "hardware" ? "var(--color-neon-green)" : "#666",
                color: result.mode === "hardware" ? "var(--color-neon-green)" : "#999",
              }}>
                MODE: {result.mode?.toUpperCase()}
              </span>
            </div>

            {/* QR Code + Verified Badge */}
            <div className="flex-grow flex items-end justify-between pt-3 mt-auto border-t border-gray-800">
              {/* QR Code */}
              <div className="flex flex-col space-y-1.5">
                <h3 className="text-[10px] text-gray-500 uppercase tracking-[0.2em]">
                  Seal Identity
                </h3>
                <div className="bg-white p-1.5 w-max rounded-sm">
                  <QRCodeSVG 
                    value="https://ozikseal.vercel.app" 
                    size={68} 
                    level="L" 
                  />
                </div>
                <span className="text-[10px] text-zinc-500 font-mono mt-1">
                  ozikseal.vercel.app
                </span>
              </div>

              {/* VERIFIED Badge */}
              <div
                className="px-4 py-2 text-sm font-bold transform -skew-x-12"
                style={{
                  backgroundColor: "var(--color-neon-green)",
                  color: "black",
                  boxShadow: "0 0 15px var(--color-neon-green), 0 0 30px rgba(57,255,20,0.3)",
                }}
              >
                <div className="transform skew-x-12 flex items-center gap-2">
                  <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="3" d="M5 13l4 4L19 7" />
                  </svg>
                  <span>DIGITAL SEAL VERIFIED</span>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* ─── ERROR STATE ─── */}
        {state === "error" && (
          <div className="h-full flex flex-col items-center justify-center space-y-3 text-red-500">
            <svg className="w-10 h-10" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4.5c-.77-.833-2.694-.833-3.464 0L3.34 16.5c-.77.833.192 2.5 1.732 2.5z" />
            </svg>
            <p className="text-sm font-semibold">{error || "An unknown error occurred."}</p>
            <p className="text-xs text-gray-500">Check backend connection and try again.</p>
          </div>
        )}
      </div>

      {/* Terminal Footer — System Info */}
      <div className="mt-3 flex justify-between text-[10px] text-gray-600 font-mono">
        <span>SYS_CLK: 50MHz</span>
        <span>CORE_TEMP: 42°C</span>
        <span>CYCLES: 64</span>
      </div>
    </section>
  );
}
