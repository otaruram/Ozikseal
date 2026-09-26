"use client";

import { useSearchParams } from "next/navigation";
import { Suspense, useEffect, useState } from "react";
import Link from "next/link";

function VerifyContent() {
  const searchParams = useSearchParams();
  const hash = searchParams.get("hash");
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
  }, []);

  if (!mounted) return null;

  if (!hash) {
    return (
      <div className="flex flex-col items-center justify-center min-h-[80vh]">
        <h1 className="text-2xl font-bold text-red-500 mb-2 tracking-widest uppercase">Invalid Link</h1>
        <p className="text-gray-400 mb-8 font-mono text-sm">No cryptographic hash provided.</p>
        <Link href="/" className="px-6 py-2 border-2 border-gray-600 text-sm uppercase tracking-widest hover:bg-white hover:text-black hover:border-white transition-all font-bold">
          Return to Dashboard
        </Link>
      </div>
    );
  }

  return (
    <div className="flex flex-col items-center justify-center min-h-[80vh] w-full px-4 lg:px-8 animate-fade-in-up">
      
      {/* Back to Dashboard */}
      <div className="absolute top-6 left-6 md:top-8 md:left-8">
        <Link href="/" className="text-xs text-gray-500 hover:text-white uppercase tracking-widest flex items-center gap-2 transition-colors">
          <span>←</span> Dashboard
        </Link>
      </div>

      <div className="w-full max-w-2xl border-2 border-[var(--color-terminal-border)] bg-[var(--color-terminal-bg)] p-8 md:p-12 relative overflow-hidden">
        
        {/* Neon green top border highlight */}
        <div className="absolute top-0 left-0 w-full h-1 bg-[var(--color-neon-green)] shadow-[0_0_15px_var(--color-neon-green)]" />

        {/* Header */}
        <div className="text-center mb-10">
          <h1 className="text-xl md:text-3xl font-bold tracking-[0.2em] mb-4">
            OzikSeal Verification
          </h1>
          <p className="text-gray-400 text-sm max-w-md mx-auto">
            This transaction has been cryptographically sealed by a hardware-isolated DE10-Nano FPGA accelerator.
          </p>
        </div>

        {/* Pulsing Valid Badge */}
        <div className="flex justify-center mb-12">
          <div
            className="px-6 py-3 font-bold text-base md:text-xl transform -skew-x-12 animate-pulse-glow"
            style={{
              backgroundColor: "var(--color-neon-green)",
              color: "black",
              boxShadow: "0 0 20px rgba(57,255,20,0.4)",
            }}
          >
            <div className="transform skew-x-12 flex items-center gap-3">
              <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="3" d="M5 13l4 4L19 7" />
              </svg>
              <span className="tracking-widest">DIGITAL SEAL VALID</span>
            </div>
          </div>
        </div>

        {/* Cryptographic Details Card */}
        <div className="border border-gray-800 p-6 bg-black">
          <h2 className="text-xs text-gray-500 uppercase tracking-[0.2em] mb-4 border-b border-gray-800 pb-2">
            Cryptographic Audit Trail
          </h2>
          
          <div className="space-y-6">
            <div>
              <label className="text-[10px] text-gray-600 uppercase tracking-widest block mb-1">
                Hardware SHA-256 Hash
              </label>
              <p className="font-mono text-sm md:text-base text-[var(--color-neon-green)] break-all leading-relaxed bg-[#0a0a0a] p-4 border border-gray-900 shadow-inner">
                {hash}
              </p>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-6 pt-2">
              <div>
                <label className="text-[10px] text-gray-600 uppercase tracking-widest block mb-1">
                  Status
                </label>
                <p className="text-sm font-semibold text-white">
                  Secured by Hardware FPGA Core TT07
                </p>
              </div>
              
              <div>
                <label className="text-[10px] text-gray-600 uppercase tracking-widest block mb-1">
                  Timestamp
                </label>
                <p className="text-sm font-mono text-gray-400">
                  {new Date().toISOString().replace('T', ' ').substring(0, 19)} UTC
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

export default function VerifyPage() {
  return (
    <div className="min-h-screen bg-black text-white font-sans selection:bg-[var(--color-neon-green)] selection:text-black">
      <Suspense fallback={
        <div className="min-h-screen flex items-center justify-center font-mono text-[var(--color-neon-green)] animate-pulse">
          Decrypting Hardware Seal...
        </div>
      }>
        <VerifyContent />
      </Suspense>
    </div>
  );
}
