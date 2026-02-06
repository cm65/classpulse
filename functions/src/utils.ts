/**
 * Pure utility functions extracted for testability.
 * These are shared between Cloud Functions and tests.
 */

import * as functions from "firebase-functions";

interface LogContext {
  functionName: string;
  instituteId?: string;
  userId?: string;
  [key: string]: unknown;
}

interface StructuredLogger {
  info: (message: string, extra?: Record<string, unknown>) => void;
  warn: (message: string, extra?: Record<string, unknown>) => void;
  error: (message: string, extra?: Record<string, unknown>) => void;
}

/**
 * Create a structured logger that auto-injects function context into every log entry.
 * Usage: const log = createLogger("onAttendanceSubmit", { instituteId, userId });
 */
export function createLogger(
  functionName: string,
  ctx?: Omit<LogContext, "functionName">
): StructuredLogger {
  const base: LogContext = {functionName, ...ctx};
  return {
    info: (message: string, extra?: Record<string, unknown>) =>
      functions.logger.info(message, {...base, ...extra}),
    warn: (message: string, extra?: Record<string, unknown>) =>
      functions.logger.warn(message, {...base, ...extra}),
    error: (message: string, extra?: Record<string, unknown>) =>
      functions.logger.error(message, {...base, ...extra}),
  };
}

/**
 * Format phone number to international format
 */
export function formatPhoneNumber(phone: string): string {
  const cleaned = phone.replace(/[^\d]/g, "");
  if (cleaned.length === 10) {
    return `+91${cleaned}`; // Default to India
  }
  if (cleaned.length === 12 && cleaned.startsWith("91")) {
    return `+${cleaned}`;
  }
  return phone.startsWith("+") ? phone : `+${cleaned}`;
}

/**
 * Validate Indian phone number (10 digits starting with 6-9, or with 91 prefix)
 */
export function isValidPhone(phone: string): boolean {
  const cleaned = phone.replace(/[^\d]/g, "");
  if (cleaned.length === 10) {
    return /^[6-9]\d{9}$/.test(cleaned);
  }
  if (cleaned.length === 12 && cleaned.startsWith("91")) {
    return /^91[6-9]\d{9}$/.test(cleaned);
  }
  return false;
}

/**
 * Format SMS message (shorter, within 160 chars)
 */
export function formatSmsMessage(
  studentName: string,
  status: "present" | "absent" | "late",
  instituteName: string,
  batchName: string,
  date: Date
): string {
  const dateStr = date.toLocaleDateString("en-IN", {
    day: "numeric",
    month: "short",
  });

  const statusText = status === "absent" ? "ABSENT from" :
    status === "late" ? "LATE to" : "attended";

  return `${instituteName}: ${studentName} was ${statusText} ${batchName} on ${dateStr}.`;
}
