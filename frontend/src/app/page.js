/**
 * ============================================================================
 * OzikSeal Frontend — Main Dashboard Page
 * ============================================================================
 * Purpose: The single-page dashboard that orchestrates the full claim flow:
 *          1. User fills the Pharmacy POS form (left panel)
 *          2. Data is sent to the FastAPI backend via POST request
 *          3. FPGA Monitor (right panel) shows processing & results
 *
 * State Machine:
 *   idle → (button click) → loading → (API response) → success / error
 *
 * API: POST http://localhost:8000/api/secure-claim
 * ============================================================================
 */

"use client";

import { useState, useCallback } from "react";
import ClaimForm from "@/components/ClaimForm";
import FPGAMonitor from "@/components/FPGAMonitor";

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------
const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000";
const LOADING_DELAY_MS = 1500; // Minimum loading time for demo effect

export default function DashboardPage() {
  // -------------------------------------------------------------------------
  // State
  // -------------------------------------------------------------------------
  const [monitorState, setMonitorState] = useState("idle");   // idle | loading | success | error
  const [result, setResult] = useState(null);                  // API response data
  const [errorMsg, setErrorMsg] = useState(null);              // Error message

  // -------------------------------------------------------------------------
  // Handle form submission → API call → update monitor state
  // -------------------------------------------------------------------------
  const handleClaimSubmit = useCallback(async (formData) => {
    // Transition to loading state
    setMonitorState("loading");
    setResult(null);
    setErrorMsg(null);

    try {
      // Start both the API call and a minimum delay timer simultaneously.
      // This ensures the loading animation shows for at least LOADING_DELAY_MS
      // even if the API responds instantly (makes the demo feel more "hardware-y").
      const [apiResponse] = await Promise.all([
        fetch(`${API_BASE_URL}/api/secure-claim`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(formData),
        }),
        new Promise((resolve) => setTimeout(resolve, LOADING_DELAY_MS)),
      ]);

      if (!apiResponse.ok) {
        const errorData = await apiResponse.json().catch(() => ({}));
        throw new Error(
          errorData.detail || `Server responded with ${apiResponse.status}`
        );
      }

      const data = await apiResponse.json();

      // Transition to success state
      setResult(data);
      setMonitorState("success");

    } catch (err) {
      // Transition to error state
      setErrorMsg(err.message || "Failed to connect to backend.");
      setMonitorState("error");
    }
  }, []);

  // -------------------------------------------------------------------------
  // Render
  // -------------------------------------------------------------------------
  return (
    <>
      {/* ─── Top Header ─── */}
      <header className="flex flex-col md:flex-row justify-between items-center px-6 lg:px-8 py-4 border-b-2 border-black gap-4 md:gap-0">
        <div className="flex items-center gap-4 text-center md:text-left">
          <img src="/logo.svg" alt="OzikSeal Logo" className="w-8 h-8" />
          <h1 className="text-base sm:text-lg lg:text-xl font-bold tracking-tight">
            OzikSeal | Hardware Crypto-Accelerator
          </h1>
        </div>
        <div className="flex items-center gap-2">
          <div className="w-2.5 h-2.5 rounded-full bg-[var(--color-neon-green)] animate-pulse-glow" />
          <span className="text-xs sm:text-sm font-semibold tracking-wide">
            Status: DE10-Nano Connected
          </span>
        </div>
      </header>

      {/* ─── Main Split-Screen Body ─── */}
      <main className="flex-grow flex flex-col md:flex-row">
        <ClaimForm
          onSubmit={handleClaimSubmit}
          isLoading={monitorState === "loading"}
        />
        <FPGAMonitor
          state={monitorState}
          result={result}
          error={errorMsg}
        />
      </main>
    </>
  );
}
