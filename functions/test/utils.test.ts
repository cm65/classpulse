import {formatPhoneNumber, isValidPhone, formatSmsMessage} from "../src/utils";

describe("formatPhoneNumber", () => {
  test("adds +91 to 10-digit Indian number", () => {
    expect(formatPhoneNumber("9876543210")).toBe("+919876543210");
  });

  test("adds + to 12-digit number with 91 prefix", () => {
    expect(formatPhoneNumber("919876543210")).toBe("+919876543210");
  });

  test("strips non-numeric characters", () => {
    expect(formatPhoneNumber("+91 98765 43210")).toBe("+919876543210");
    expect(formatPhoneNumber("987-654-3210")).toBe("+919876543210");
  });

  test("preserves + prefix for already formatted numbers", () => {
    expect(formatPhoneNumber("+919876543210")).toBe("+919876543210");
  });

  test("handles numbers with country code without +", () => {
    expect(formatPhoneNumber("919876543210")).toBe("+919876543210");
  });
});

describe("isValidPhone", () => {
  test("accepts valid 10-digit numbers starting with 6-9", () => {
    expect(isValidPhone("9876543210")).toBe(true);
    expect(isValidPhone("8765432109")).toBe(true);
    expect(isValidPhone("7654321098")).toBe(true);
    expect(isValidPhone("6543210987")).toBe(true);
  });

  test("accepts valid numbers with 91 prefix", () => {
    expect(isValidPhone("919876543210")).toBe(true);
    expect(isValidPhone("+919876543210")).toBe(true);
  });

  test("rejects numbers starting with 0-5", () => {
    expect(isValidPhone("0123456789")).toBe(false);
    expect(isValidPhone("1234567890")).toBe(false);
    expect(isValidPhone("5555555555")).toBe(false);
  });

  test("rejects wrong-length numbers", () => {
    expect(isValidPhone("12345")).toBe(false);
    expect(isValidPhone("98765432101234")).toBe(false);
    expect(isValidPhone("")).toBe(false);
  });

  test("strips non-numeric before validating", () => {
    expect(isValidPhone("987-654-3210")).toBe(true);
    expect(isValidPhone("+91 98765 43210")).toBe(true);
  });
});

describe("formatSmsMessage", () => {
  const testDate = new Date("2024-06-15T10:30:00Z");

  test("formats absent message", () => {
    const msg = formatSmsMessage(
      "Rahul Sharma",
      "absent",
      "Test Academy",
      "Morning Batch",
      testDate
    );
    expect(msg).toContain("Test Academy");
    expect(msg).toContain("Rahul Sharma");
    expect(msg).toContain("ABSENT from");
    expect(msg).toContain("Morning Batch");
  });

  test("formats late message", () => {
    const msg = formatSmsMessage(
      "Priya Singh",
      "late",
      "ABC Institute",
      "Evening Batch",
      testDate
    );
    expect(msg).toContain("LATE to");
  });

  test("formats present message", () => {
    const msg = formatSmsMessage(
      "John Doe",
      "present",
      "XYZ Academy",
      "Morning",
      testDate
    );
    expect(msg).toContain("attended");
  });

  test("produces message under 160 characters for typical inputs", () => {
    const msg = formatSmsMessage(
      "Rahul Sharma",
      "absent",
      "Test Academy",
      "Morning Batch",
      testDate
    );
    expect(msg.length).toBeLessThanOrEqual(160);
  });
});
