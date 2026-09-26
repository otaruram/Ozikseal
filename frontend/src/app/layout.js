/**
 * ============================================================================
 * OzikSeal Frontend — Root Layout
 * ============================================================================
 * Purpose: Configures global fonts (Geist Sans + Mono), metadata for SEO,
 *          and wraps all pages in a consistent HTML structure.
 *
 * Fonts: Using Geist (sans) and Geist Mono from next/font/google for
 *        optimal loading and zero layout shift.
 * ============================================================================
 */

import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";

// ---------------------------------------------------------------------------
// Font Configuration
// ---------------------------------------------------------------------------
const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

// ---------------------------------------------------------------------------
// SEO Metadata
// ---------------------------------------------------------------------------
export const metadata = {
  title: "OzikSeal | Hardware Crypto-Accelerator Dashboard",
  description:
    "Hardware-Accelerated Digital Trust system for BPJS/JKN healthcare claims. " +
    "Uses DE10-Nano FPGA for tamper-proof SHA-256 cryptographic sealing.",
  keywords: ["FPGA", "SHA-256", "BPJS", "healthcare", "cryptography", "DE10-Nano"],
};

// ---------------------------------------------------------------------------
// Root Layout Component
// ---------------------------------------------------------------------------
export default function RootLayout({ children }) {
  return (
    <html
      lang="en"
      className={`${geistSans.variable} ${geistMono.variable} h-full antialiased`}
    >
      <body className="min-h-full flex flex-col bg-white text-black">
        {children}
      </body>
    </html>
  );
}
