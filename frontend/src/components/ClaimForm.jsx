/**
 * ============================================================================
 * OzikSeal Frontend — ClaimForm Component
 * ============================================================================
 * Purpose: Left panel of the dashboard. Renders the Pharmacy POS input form
 *          for entering BPJS/JKN claim data. On submission, sends data to
 *          the parent component via the `onSubmit` callback.
 *
 * Props:
 *   - onSubmit(formData): Called with the form data when user clicks submit.
 *   - isLoading: Boolean — disables the button during processing.
 *
 * Design: Monochrome minimalist with black borders and clean typography.
 * ============================================================================
 */

"use client";

import { useState } from "react";

// ---------------------------------------------------------------------------
// Default form values (pre-filled for demo convenience)
// ---------------------------------------------------------------------------
const DEFAULT_VALUES = {
  patient_id: "JKN-2026-9821",
  drug_name: "Amoxicillin 500mg",
  claim_amount: "150000",
  auth_pin: "821994",
};

export default function ClaimForm({ onSubmit, isLoading = false }) {
  const [formData, setFormData] = useState(DEFAULT_VALUES);

  // -------------------------------------------------------------------------
  // Handle input changes — updates the corresponding field in state
  // -------------------------------------------------------------------------
  const handleChange = (e) => {
    const { name, value } = e.target;
    setFormData((prev) => ({ ...prev, [name]: value }));
  };

  // -------------------------------------------------------------------------
  // Handle form submission — validates and passes data to parent
  // -------------------------------------------------------------------------
  const handleSubmit = (e) => {
    e.preventDefault();
    if (isLoading) return;

    // Parse the claim amount to an integer for the API
    const payload = {
      ...formData,
      claim_amount: parseInt(formData.claim_amount, 10) || 0,
    };

    onSubmit(payload);
  };

  return (
    <section className="w-full md:w-1/2 p-8 lg:p-12 border-b-2 md:border-b-0 md:border-r-2 border-black flex flex-col">
      {/* Section Header */}
      <div className="mb-8">
        <h2 className="text-2xl lg:text-3xl font-bold tracking-tight mb-1">
          Pharmacy Claim Input
        </h2>
        <p className="text-sm text-gray-500">
          Enter transaction details to be hardware-sealed via FPGA.
        </p>
      </div>

      {/* Form */}
      <form
        className="flex-grow flex flex-col space-y-5"
        onSubmit={handleSubmit}
      >
        {/* Patient ID */}
        <div className="flex flex-col space-y-1.5">
          <label
            htmlFor="patient_id"
            className="text-xs font-bold uppercase tracking-[0.2em] text-gray-700"
          >
            Patient ID
          </label>
          <input
            id="patient_id"
            name="patient_id"
            type="text"
            value={formData.patient_id}
            onChange={handleChange}
            placeholder="JKN-XXXX-XXXX"
            className="p-3 border-2 border-black bg-transparent font-mono text-sm focus:outline-none focus:ring-2 focus:ring-black transition-shadow"
            required
          />
        </div>

        {/* Drug Name */}
        <div className="flex flex-col space-y-1.5">
          <label
            htmlFor="drug_name"
            className="text-xs font-bold uppercase tracking-[0.2em] text-gray-700"
          >
            Drug Name
          </label>
          <input
            id="drug_name"
            name="drug_name"
            type="text"
            value={formData.drug_name}
            onChange={handleChange}
            placeholder="e.g., Amoxicillin 500mg"
            className="p-3 border-2 border-black bg-transparent font-mono text-sm focus:outline-none focus:ring-2 focus:ring-black transition-shadow"
            required
          />
        </div>

        {/* Claim Amount */}
        <div className="flex flex-col space-y-1.5">
          <label
            htmlFor="claim_amount"
            className="text-xs font-bold uppercase tracking-[0.2em] text-gray-700"
          >
            Claim Amount (IDR)
          </label>
          <div className="relative">
            <span className="absolute left-3 top-1/2 -translate-y-1/2 text-sm font-mono text-gray-500">
              Rp
            </span>
            <input
              id="claim_amount"
              name="claim_amount"
              type="text"
              value={formData.claim_amount}
              onChange={handleChange}
              placeholder="150000"
              className="w-full p-3 pl-10 border-2 border-black bg-transparent font-mono text-sm focus:outline-none focus:ring-2 focus:ring-black transition-shadow"
              required
            />
          </div>
        </div>

        {/* Authentication PIN */}
        <div className="flex flex-col space-y-1.5">
          <label
            htmlFor="auth_pin"
            className="text-xs font-bold uppercase tracking-[0.2em] text-gray-700"
          >
            Patient Auth PIN
          </label>
          <input
            id="auth_pin"
            name="auth_pin"
            type="password"
            maxLength={6}
            value={formData.auth_pin}
            onChange={handleChange}
            placeholder="••••••"
            className="p-3 border-2 border-black bg-transparent font-mono text-sm tracking-[0.5em] focus:outline-none focus:ring-2 focus:ring-black transition-shadow"
            required
          />
        </div>

        {/* Submit Button */}
        <div className="pt-4 mt-auto">
          <button
            type="submit"
            disabled={isLoading}
            className="w-full bg-black text-white font-bold py-4 px-6 border-2 border-black text-sm uppercase tracking-[0.15em] transition-all duration-200 hover:bg-white hover:text-black disabled:opacity-40 disabled:cursor-not-allowed disabled:hover:bg-black disabled:hover:text-white cursor-pointer"
          >
            {isLoading
              ? "⏳ Processing..."
              : "Secure & Transmit to Hardware"}
          </button>
        </div>
      </form>
    </section>
  );
}
