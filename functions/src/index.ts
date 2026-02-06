import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import {defineSecret} from "firebase-functions/params";
import twilio from "twilio";
import axios from "axios";
import * as crypto from "crypto";
import {isValidPhone, createLogger} from "./utils";

admin.initializeApp();

const db = admin.firestore();

// =============================================================================
// SECRETS & CONFIGURATION
// =============================================================================

// Twilio credentials (for WhatsApp Business API)
const twilioAccountSid = defineSecret("TWILIO_ACCOUNT_SID");
const twilioAuthToken = defineSecret("TWILIO_AUTH_TOKEN");

// MSG91 credentials (for SMS - cheaper for India)
// Optional - only needed if using MSG91 as SMS provider
const msg91AuthKey = defineSecret("MSG91_AUTH_KEY");

// Environment variables
const config = {
  // Primary notification channel: "whatsapp" or "sms"
  primaryChannel: process.env.PRIMARY_CHANNEL || "whatsapp",
  // SMS Provider: "msg91" (recommended for India) or "twilio"
  smsProvider: process.env.SMS_PROVIDER || "msg91",
  // Twilio WhatsApp number (sandbox or business)
  twilioWhatsAppNumber: process.env.TWILIO_WHATSAPP_NUMBER || "+14155238886",
  // Twilio SMS number (optional fallback)
  twilioSmsNumber: process.env.TWILIO_SMS_NUMBER,
  // MSG91 Sender ID (6 chars, e.g., "CLSPLS")
  msg91SenderId: process.env.MSG91_SENDER_ID || "CLSPLS",
  // MSG91 DLT Template IDs (required for India)
  msg91AbsentTemplateId: process.env.MSG91_ABSENT_TEMPLATE_ID,
  msg91LateTemplateId: process.env.MSG91_LATE_TEMPLATE_ID,
  // WhatsApp Content Template SIDs (for Business API)
  whatsappAbsentTemplateSid: process.env.WHATSAPP_ABSENT_TEMPLATE_SID,
  whatsappLateTemplateSid: process.env.WHATSAPP_LATE_TEMPLATE_SID,
  whatsappPresentTemplateSid: process.env.WHATSAPP_PRESENT_TEMPLATE_SID,
  // App download link
  appDownloadLink: process.env.APP_DOWNLOAD_LINK ||
    "https://apps.apple.com/app/classpulse/id123456789",
};

// =============================================================================
// TYPES
// =============================================================================

type TwilioClient = ReturnType<typeof twilio>;

interface AttendanceRecord {
  instituteId: string;
  batchId: string;
  date: admin.firestore.Timestamp;
  submittedBy: string;
  submittedAt: admin.firestore.Timestamp;
}

interface StudentAttendance {
  studentId: string;
  studentName: string;
  parentPhone: string;
  parentName?: string;
  status: "present" | "absent" | "late";
  notificationStatus: string;
  notificationChannel: string;
  notificationError?: string;
  notificationSid?: string;
  notifiedAt?: admin.firestore.Timestamp;
  retryCount?: number;
}

interface Institute {
  name: string;
  settings?: {
    notificationsEnabled?: boolean;
    notifyForPresent?: boolean;
    notificationTemplates?: {
      absentTemplate?: string;
      lateTemplate?: string;
      presentTemplate?: string;
    };
  };
}

interface Batch {
  name: string;
}

interface NotificationResult {
  success: boolean;
  channel?: "whatsapp" | "sms";
  sid?: string;
  error?: string;
  provider?: string;
}

// =============================================================================
// NOTIFICATION PROVIDERS
// =============================================================================

/**
 * Get Twilio client (lazy initialization)
 */
function getTwilioClient(): TwilioClient | null {
  const accountSid = twilioAccountSid.value();
  const authToken = twilioAuthToken.value();
  if (accountSid && authToken) {
    return twilio(accountSid, authToken);
  }
  return null;
}

/**
 * Send WhatsApp message via Twilio
 */
async function sendWhatsAppMessage(
  client: TwilioClient,
  to: string,
  message: string,
  templateName?: string,
  templateParams?: Record<string, string>
): Promise<NotificationResult> {
  try {
    // For WhatsApp Business API with templates
    const messageOptions: {
      from: string;
      to: string;
      body?: string;
      contentSid?: string;
      contentVariables?: string;
    } = {
      from: `whatsapp:${config.twilioWhatsAppNumber}`,
      to: `whatsapp:${to}`,
    };

    // Use template if available (required for Business API outside 24-hour window)
    if (templateName && templateParams) {
      // For Twilio Content API templates
      functions.logger.info(`Using Content Template: ${templateName}`);
      messageOptions.contentSid = templateName;
      messageOptions.contentVariables = JSON.stringify(templateParams);
    } else {
      // Fallback to plain message (works for sandbox or within 24-hour window)
      functions.logger.warn(`No template provided, using plain message. templateName=${templateName}`);
      messageOptions.body = message;
    }

    const result = await client.messages.create(messageOptions);

    return {
      success: true,
      channel: "whatsapp",
      sid: result.sid,
      provider: "twilio",
    };
  } catch (error) {
    const errorMessage = (error as Error).message;
    functions.logger.warn(`WhatsApp send failed: ${errorMessage}`);
    return {
      success: false,
      error: errorMessage,
      provider: "twilio",
    };
  }
}

/**
 * Send SMS via MSG91 (recommended for India - cheaper & DLT compliant)
 */
async function sendMsg91Sms(
  to: string,
  message: string,
  templateId?: string
): Promise<NotificationResult> {
  const authKey = msg91AuthKey.value();
  if (!authKey) {
    return {success: false, error: "MSG91 not configured", provider: "msg91"};
  }

  try {
    // Format phone number for MSG91 (requires country code without +)
    const phoneNumber = to.replace("+", "");

    const response = await axios.post(
      "https://api.msg91.com/api/v5/flow/",
      {
        template_id: templateId,
        sender: config.msg91SenderId,
        short_url: "0",
        mobiles: phoneNumber,
        VAR1: message, // Variable content
      },
      {
        headers: {
          "authkey": authKey,
          "Content-Type": "application/json",
        },
      }
    );

    if (response.data.type === "success") {
      return {
        success: true,
        channel: "sms",
        sid: response.data.request_id,
        provider: "msg91",
      };
    } else {
      return {
        success: false,
        error: response.data.message || "MSG91 error",
        provider: "msg91",
      };
    }
  } catch (error) {
    const errorMessage = (error as Error).message;
    functions.logger.warn(`MSG91 send failed: ${errorMessage}`);
    return {
      success: false,
      error: errorMessage,
      provider: "msg91",
    };
  }
}

/**
 * Send SMS via Twilio (fallback)
 */
async function sendTwilioSms(
  client: TwilioClient,
  to: string,
  message: string
): Promise<NotificationResult> {
  if (!config.twilioSmsNumber) {
    return {success: false, error: "Twilio SMS not configured", provider: "twilio"};
  }

  try {
    const result = await client.messages.create({
      from: config.twilioSmsNumber,
      to: to,
      body: message,
    });

    return {
      success: true,
      channel: "sms",
      sid: result.sid,
      provider: "twilio",
    };
  } catch (error) {
    const errorMessage = (error as Error).message;
    functions.logger.warn(`Twilio SMS send failed: ${errorMessage}`);
    return {
      success: false,
      error: errorMessage,
      provider: "twilio",
    };
  }
}

// =============================================================================
// MESSAGE FORMATTING
// =============================================================================

/**
 * Format phone number to international format
 */
function formatPhoneNumber(phone: string): string {
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
 * Format WhatsApp message (rich formatting)
 */
function formatWhatsAppMessage(
  record: StudentAttendance,
  institute: Institute,
  batch: Batch,
  date: Date
): string {
  const dateStr = date.toLocaleDateString("en-IN", {
    weekday: "long",
    day: "numeric",
    month: "long",
    year: "numeric",
  });

  const templates = institute.settings?.notificationTemplates;

  if (record.status === "absent") {
    const template = templates?.absentTemplate ||
      "Dear Parent,\n\n" +
      "This is to inform you that *{student}* was *ABSENT* from " +
      "*{batch}* on *{date}*.\n\n" +
      "If this absence was unplanned, please contact the institute.\n\n" +
      "Regards,\n{institute}";

    return template
      .replace("{student}", record.studentName)
      .replace("{batch}", batch.name)
      .replace("{date}", dateStr)
      .replace("{institute}", institute.name);
  } else if (record.status === "late") {
    const template = templates?.lateTemplate ||
      "Dear Parent,\n\n" +
      "*{student}* arrived *LATE* to *{batch}* on *{date}*.\n\n" +
      "Please ensure timely attendance for better learning.\n\n" +
      "Regards,\n{institute}";

    return template
      .replace("{student}", record.studentName)
      .replace("{batch}", batch.name)
      .replace("{date}", dateStr)
      .replace("{institute}", institute.name);
  }

  // Present (optional notification)
  const template = templates?.presentTemplate ||
    "Dear Parent,\n\n" +
    "*{student}* has arrived for *{batch}* on *{date}*.\n\n" +
    "Regards,\n{institute}";

  return template
    .replace("{student}", record.studentName)
    .replace("{batch}", batch.name)
    .replace("{date}", dateStr)
    .replace("{institute}", institute.name);
}

/**
 * Format SMS message (shorter, within 160 chars)
 */
function formatSmsMessage(
  record: StudentAttendance,
  institute: Institute,
  batch: Batch,
  date: Date
): string {
  const dateStr = date.toLocaleDateString("en-IN", {
    day: "numeric",
    month: "short",
  });

  const statusText = record.status === "absent" ? "ABSENT from" :
    record.status === "late" ? "LATE to" : "attended";

  // Keep SMS short for cost efficiency
  return `${institute.name}: ${record.studentName} was ${statusText} ${batch.name} on ${dateStr}.`;
}

/**
 * Get WhatsApp Content Template SID and variables based on status
 */
function getWhatsAppTemplate(
  record: StudentAttendance,
  batch: Batch,
  date: Date
): {sid: string | undefined; variables: Record<string, string>} {
  const dateStr = date.toLocaleDateString("en-IN", {
    weekday: "short",
    day: "numeric",
    month: "short",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });

  // Variables match template: {{1}} = student name, {{2}} = batch name, {{3}} = date
  const variables = {
    "1": record.studentName,
    "2": batch.name,
    "3": dateStr,
  };

  let sid: string | undefined;
  switch (record.status) {
  case "absent":
    sid = config.whatsappAbsentTemplateSid;
    break;
  case "late":
    sid = config.whatsappLateTemplateSid;
    break;
  case "present":
    sid = config.whatsappPresentTemplateSid;
    break;
  }

  return {sid, variables};
}

// =============================================================================
// NOTIFICATION LOGIC
// =============================================================================

/**
 * Send notification with fallback logic
 */
async function sendNotification(
  recordRef: admin.firestore.DocumentReference,
  record: StudentAttendance,
  institute: Institute,
  batch: Batch,
  date: Date
): Promise<void> {
  const phoneNumber = formatPhoneNumber(record.parentPhone);
  const whatsappMessage = formatWhatsAppMessage(record, institute, batch, date);
  const smsMessage = formatSmsMessage(record, institute, batch, date);

  const log = createLogger("sendNotification");
  log.info("Sending notification", {phone: phoneNumber, studentName: record.studentName});

  let result: NotificationResult = {success: false, error: "No provider configured"};
  const twilioClient = getTwilioClient();

  // Get WhatsApp template for this status
  const template = getWhatsAppTemplate(record, batch, date);

  log.info("Using template", {status: record.status, templateSid: template.sid});

  // Try primary channel first
  if (config.primaryChannel === "whatsapp" && twilioClient) {
    // Use Content Template for WhatsApp Business API
    log.info("Sending WhatsApp with template", {templateSid: template.sid});
    result = await sendWhatsAppMessage(
      twilioClient,
      phoneNumber,
      whatsappMessage, // fallback message if template not configured
      template.sid,
      template.variables
    );
  } else if (config.primaryChannel === "sms") {
    if (config.smsProvider === "msg91") {
      const templateId = record.status === "absent" ?
        config.msg91AbsentTemplateId : config.msg91LateTemplateId;
      result = await sendMsg91Sms(phoneNumber, smsMessage, templateId);
    } else if (twilioClient) {
      result = await sendTwilioSms(twilioClient, phoneNumber, smsMessage);
    }
  }

  // Fallback to SMS if WhatsApp failed
  if (!result.success && config.primaryChannel === "whatsapp") {
    log.info("WhatsApp failed, trying SMS fallback", {phone: phoneNumber});

    if (config.smsProvider === "msg91") {
      const templateId = record.status === "absent" ?
        config.msg91AbsentTemplateId : config.msg91LateTemplateId;
      result = await sendMsg91Sms(phoneNumber, smsMessage, templateId);
    } else if (twilioClient && config.twilioSmsNumber) {
      result = await sendTwilioSms(twilioClient, phoneNumber, smsMessage);
    }
  }

  // Update record with result
  if (result.success) {
    await recordRef.update({
      notificationStatus: "sent",
      notificationChannel: result.channel,
      notificationSid: result.sid,
      notificationProvider: result.provider,
      notifiedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    log.info("Notification sent", {
      phone: phoneNumber,
      provider: result.provider,
      channel: result.channel,
    });
  } else {
    await recordRef.update({
      notificationStatus: "failed",
      notificationError: result.error,
      notificationProvider: result.provider,
      retryCount: (record.retryCount || 0) + 1,
    });
    log.error("Notification failed", {
      phone: phoneNumber,
      provider: result.provider,
      error: result.error,
    });
  }
}

// =============================================================================
// CLOUD FUNCTIONS
// =============================================================================

/**
 * Triggered when attendance is submitted.
 * Sends notifications to parents of absent/late students.
 */
export const onAttendanceSubmit = functions
  .region("asia-south1")
  .runWith({
    secrets: [twilioAccountSid, twilioAuthToken, msg91AuthKey],
    timeoutSeconds: 300,
    memory: "512MB",
  })
  .firestore.document("institutes/{instituteId}/attendance/{attendanceId}")
  .onCreate(async (snap, context) => {
    const {instituteId, attendanceId} = context.params;
    const attendance = snap.data() as AttendanceRecord;
    const log = createLogger("onAttendanceSubmit", {instituteId});

    log.info("Processing attendance", {attendanceId});

    try {
      // Get institute details
      const instituteDoc = await db.collection("institutes").doc(instituteId).get();
      if (!instituteDoc.exists) {
        log.error("Institute not found", {attendanceId});
        return;
      }
      const institute = instituteDoc.data() as Institute;

      // Check if notifications are enabled
      if (institute.settings?.notificationsEnabled === false) {
        log.info("Notifications disabled, skipping", {attendanceId});
        return;
      }

      // Get batch details
      const batchDoc = await db
        .collection("institutes")
        .doc(instituteId)
        .collection("batches")
        .doc(attendance.batchId)
        .get();

      if (!batchDoc.exists) {
        log.error("Batch not found", {attendanceId, batchId: attendance.batchId});
        return;
      }
      const batch = batchDoc.data() as Batch;

      // Retry reading records subcollection with exponential backoff
      // (records may not be written yet due to Firestore eventual consistency)
      const retryDelays = [500, 1000, 2000];
      let recordsSnapshot = await snap.ref.collection("records").get();
      for (const delay of retryDelays) {
        if (recordsSnapshot.size > 0) break;
        log.warn("Records empty, retrying", {attendanceId, retryDelayMs: delay});
        await new Promise((resolve) => setTimeout(resolve, delay));
        recordsSnapshot = await snap.ref.collection("records").get();
      }
      if (recordsSnapshot.empty) {
        log.warn("No records found after retries, skipping", {attendanceId});
        return;
      }

      const records = recordsSnapshot.docs.map((doc) => ({
        id: doc.id,
        ...doc.data(),
      })) as (StudentAttendance & {id: string})[];

      // Filter students to notify - notify for ALL statuses by default
      // Parents want to know when their child arrives, not just when absent
      const notifyStatuses: string[] = ["absent", "late", "present"];
      if (institute.settings?.notifyForPresent === false) {
        // Only exclude present if explicitly disabled
        notifyStatuses.splice(notifyStatuses.indexOf("present"), 1);
      }

      const toNotify = records.filter((r) => {
        if (!notifyStatuses.includes(r.status)) return false;
        if (!r.parentPhone || !isValidPhone(r.parentPhone)) {
          if (r.parentPhone) {
            log.warn("Skipping invalid phone number", {
              studentName: r.studentName,
              phone: r.parentPhone,
              attendanceId: snap.id,
            });
          }
          return false;
        }
        return true;
      });

      log.info("Sending notifications", {
        attendanceId,
        toNotify: toNotify.length,
        totalRecords: records.length,
      });

      if (toNotify.length === 0) {
        log.info("No notifications to send", {attendanceId});
        return;
      }

      const attendanceDate = attendance.date?.toDate() || new Date();

      // Process in chunks with rate limiting
      const chunkSize = 10;
      for (let i = 0; i < toNotify.length; i += chunkSize) {
        const chunk = toNotify.slice(i, i + chunkSize);
        await Promise.all(
          chunk.map((record) =>
            sendNotification(
              snap.ref.collection("records").doc(record.id),
              record,
              institute,
              batch,
              attendanceDate
            )
          )
        );

        // Rate limiting delay between chunks
        if (i + chunkSize < toNotify.length) {
          await new Promise((resolve) => setTimeout(resolve, 1000));
        }
      }

      // Update attendance document with notification summary
      const sentCount = toNotify.length;
      await snap.ref.update({
        notificationsSent: sentCount,
        notificationsProcessedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      log.info("Completed processing attendance", {attendanceId, sentCount});
    } catch (error) {
      log.error("Error processing attendance", {
        attendanceId,
        error: (error as Error).message,
      });
    }
  });

/**
 * Retry failed notifications (callable function)
 */
export const retryNotification = functions
  .region("asia-south1")
  .runWith({secrets: [twilioAccountSid, twilioAuthToken, msg91AuthKey]})
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Must be authenticated");
    }

    const {instituteId, attendanceId, studentId} = data;

    // Verify caller has teacher record for this institute
    const teacherDoc = await db.collection("teachers").doc(context.auth.uid).get();
    if (!teacherDoc.exists || teacherDoc.data()?.instituteId !== instituteId) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Not authorized for this institute"
      );
    }

    const recordRef = db
      .collection("institutes")
      .doc(instituteId)
      .collection("attendance")
      .doc(attendanceId)
      .collection("records")
      .doc(studentId);

    const recordDoc = await recordRef.get();
    if (!recordDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Record not found");
    }

    const record = recordDoc.data() as StudentAttendance;

    // Check retry limit
    if ((record.retryCount || 0) >= 3) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Maximum retry attempts reached"
      );
    }

    const attendanceDoc = await recordRef.parent.parent?.get();
    if (!attendanceDoc?.exists) {
      throw new functions.https.HttpsError("not-found", "Attendance not found");
    }

    const attendance = attendanceDoc.data() as AttendanceRecord;
    const instituteDoc = await db.collection("institutes").doc(instituteId).get();
    const institute = instituteDoc.data() as Institute;

    const batchDoc = await db
      .collection("institutes")
      .doc(instituteId)
      .collection("batches")
      .doc(attendance.batchId)
      .get();
    const batch = batchDoc.data() as Batch;

    await sendNotification(
      recordRef,
      record,
      institute,
      batch,
      attendance.date.toDate()
    );

    return {success: true};
  });

/**
 * Webhook for Twilio delivery status callbacks
 */
export const twilioWebhook = functions
  .region("asia-south1")
  .runWith({secrets: [twilioAuthToken]})
  .https.onRequest(async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method not allowed");
      return;
    }

    try {
      // Validate Twilio signature
      const authToken = twilioAuthToken.value();
      if (authToken) {
        const twilioSignature = req.headers["x-twilio-signature"] as string;
        const url = `https://${req.hostname}${req.originalUrl}`;
        const isValid = twilio.validateRequest(
          authToken,
          twilioSignature || "",
          url,
          req.body
        );
        if (!isValid) {
          functions.logger.warn("Invalid Twilio webhook signature", {
            webhookType: "twilio",
          });
          res.status(403).send("Forbidden");
          return;
        }
      }

      const {MessageSid, MessageStatus, ErrorCode} = req.body || {};

      if (!MessageSid || !MessageStatus) {
        res.status(400).send("Bad request");
        return;
      }

      functions.logger.info("Twilio webhook received", {
        webhookType: "twilio",
        messageId: MessageSid,
        status: MessageStatus,
        errorCode: ErrorCode || null,
      });

      res.status(200).send("OK");
    } catch (error) {
      functions.logger.error("Twilio webhook error", {
        webhookType: "twilio",
        error: (error as Error).message,
      });
      res.status(500).send("Internal error");
    }
  });

/**
 * Webhook for MSG91 delivery status callbacks
 */
export const msg91Webhook = functions
  .region("asia-south1")
  .runWith({secrets: [msg91AuthKey]})
  .https.onRequest(async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method not allowed");
      return;
    }

    try {
      // Validate MSG91 request via auth key in header
      const authKey = msg91AuthKey.value();
      if (authKey) {
        const requestAuthKey = req.headers["authkey"] as string;
        if (requestAuthKey && requestAuthKey !== authKey) {
          functions.logger.warn("Invalid MSG91 webhook auth key", {
            webhookType: "msg91",
          });
          res.status(403).send("Forbidden");
          return;
        }
      }

      const {requestId, status, mobile} = req.body || {};

      if (!requestId) {
        res.status(400).send("Bad request");
        return;
      }

      functions.logger.info("MSG91 webhook received", {
        webhookType: "msg91",
        messageId: requestId,
        status,
        mobile,
      });

      res.status(200).send("OK");
    } catch (error) {
      functions.logger.error("MSG91 webhook error", {
        webhookType: "msg91",
        error: (error as Error).message,
      });
      res.status(500).send("Internal error");
    }
  });

/**
 * Send test notification (for debugging)
 */
export const sendTestNotification = functions
  .region("asia-south1")
  .runWith({secrets: [twilioAccountSid, twilioAuthToken, msg91AuthKey]})
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Must be authenticated");
    }

    // Rate limit: 5 test notifications per user per hour
    const userId = context.auth.uid;
    const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
    const rateLimitRef = db.collection("rateLimits").doc("testNotifications");
    const recentRequests = await rateLimitRef
      .collection("requests")
      .where("userId", "==", userId)
      .where("timestamp", ">", admin.firestore.Timestamp.fromDate(oneHourAgo))
      .get();

    if (recentRequests.size >= 5) {
      throw new functions.https.HttpsError(
        "resource-exhausted",
        "Rate limit exceeded: maximum 5 test notifications per hour"
      );
    }

    // Record this request for rate limiting
    await rateLimitRef.collection("requests").add({
      userId,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    const {phoneNumber, channel} = data;

    if (!phoneNumber) {
      throw new functions.https.HttpsError("invalid-argument", "Phone number required");
    }

    if (!isValidPhone(phoneNumber)) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Invalid phone number format"
      );
    }

    const formattedPhone = formatPhoneNumber(phoneNumber);
    const testMessage = "ClassPulse Test: This is a test notification. " +
      "If you received this, notifications are working correctly!";

    let result: NotificationResult;

    if (channel === "whatsapp") {
      const twilioClient = getTwilioClient();
      if (!twilioClient) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "Twilio not configured"
        );
      }
      result = await sendWhatsAppMessage(twilioClient, formattedPhone, testMessage);
    } else {
      if (config.smsProvider === "msg91") {
        result = await sendMsg91Sms(formattedPhone, testMessage);
      } else {
        const twilioClient = getTwilioClient();
        if (!twilioClient) {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "Twilio not configured"
          );
        }
        result = await sendTwilioSms(twilioClient, formattedPhone, testMessage);
      }
    }

    if (result.success) {
      return {success: true, channel: result.channel, provider: result.provider};
    } else {
      throw new functions.https.HttpsError("internal", result.error || "Send failed");
    }
  });

// =============================================================================
// TEACHER INVITATION FUNCTIONS
// =============================================================================

interface TeacherInvitation {
  instituteId: string;
  instituteName: string;
  phone: string;
  role: "admin" | "teacher";
  invitedBy: string;
  invitedAt: admin.firestore.Timestamp;
  expiresAt: admin.firestore.Timestamp;
  isAccepted: boolean;
  smsSent?: boolean;
  smsSentAt?: admin.firestore.Timestamp;
  smsError?: string;
}

/**
 * Send invitation SMS when teacher is invited
 */
export const onTeacherInvitationCreate = functions
  .region("asia-south1")
  .runWith({secrets: [twilioAccountSid, twilioAuthToken, msg91AuthKey]})
  .firestore.document("teacherInvitations/{invitationId}")
  .onCreate(async (snap, context) => {
    const {invitationId} = context.params;
    const invitation = snap.data() as TeacherInvitation;
    const log = createLogger("onTeacherInvitationCreate", {
      instituteId: invitation.instituteId,
    });

    log.info("Processing teacher invitation", {invitationId, phone: invitation.phone});

    const phoneNumber = formatPhoneNumber(invitation.phone);
    const roleText = invitation.role === "admin" ? "administrator" : "teacher";

    const message =
      `You've been invited to join ${invitation.instituteName} as a ${roleText} ` +
      `on ClassPulse. Download: ${config.appDownloadLink}`;

    let result: NotificationResult;

    // Try MSG91 first for India numbers
    if (config.smsProvider === "msg91") {
      result = await sendMsg91Sms(phoneNumber, message);
    } else {
      const twilioClient = getTwilioClient();
      if (twilioClient && config.twilioSmsNumber) {
        result = await sendTwilioSms(twilioClient, phoneNumber, message);
      } else {
        result = {success: false, error: "SMS not configured"};
      }
    }

    if (result.success) {
      await snap.ref.update({
        smsSent: true,
        smsSentAt: admin.firestore.FieldValue.serverTimestamp(),
        smsSid: result.sid,
      });
    } else {
      await snap.ref.update({
        smsSent: false,
        smsError: result.error,
      });
    }
  });

/**
 * Resend teacher invitation SMS
 */
export const resendTeacherInvitation = functions
  .region("asia-south1")
  .runWith({secrets: [twilioAccountSid, twilioAuthToken, msg91AuthKey]})
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Must be authenticated");
    }

    const {invitationId} = data;

    const invitationRef = db.collection("teacherInvitations").doc(invitationId);
    const invitationDoc = await invitationRef.get();

    if (!invitationDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Invitation not found");
    }

    const invitation = invitationDoc.data() as TeacherInvitation;

    if (invitation.isAccepted) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Invitation already accepted"
      );
    }

    const phoneNumber = formatPhoneNumber(invitation.phone);
    const roleText = invitation.role === "admin" ? "administrator" : "teacher";

    const message =
      `Reminder: You've been invited to join ${invitation.instituteName} as a ${roleText}. ` +
      `Download ClassPulse: ${config.appDownloadLink}`;

    let result: NotificationResult;

    if (config.smsProvider === "msg91") {
      result = await sendMsg91Sms(phoneNumber, message);
    } else {
      const twilioClient = getTwilioClient();
      if (twilioClient && config.twilioSmsNumber) {
        result = await sendTwilioSms(twilioClient, phoneNumber, message);
      } else {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "SMS not configured"
        );
      }
    }

    if (result.success) {
      await invitationRef.update({
        smsSent: true,
        smsSentAt: admin.firestore.FieldValue.serverTimestamp(),
        smsSid: result.sid,
      });
      return {success: true, messageSid: result.sid};
    } else {
      throw new functions.https.HttpsError("internal", result.error || "Send failed");
    }
  });

// =============================================================================
// PAYMENT REMINDERS
// =============================================================================

interface FeeInvoice {
  studentId: string;
  batchId: string;
  finalAmount: number;
  paidAmount: number;
  dueDate: admin.firestore.Timestamp;
  status: "pending" | "partial" | "paid" | "overdue";
}

interface Student {
  name: string;
  parentPhone: string;
}

/**
 * Scheduled function to send payment reminders for overdue invoices.
 * Runs daily at 9 AM IST.
 */
export const sendPaymentReminders = functions
  .runWith({
    secrets: [twilioAccountSid, twilioAuthToken, msg91AuthKey],
    timeoutSeconds: 540,
  })
  .pubsub.schedule("0 9 * * *")
  .timeZone("Asia/Kolkata")
  .onRun(async () => {
    const log = createLogger("sendPaymentReminders");
    log.info("Starting payment reminder job");

    const startTime = Date.now();
    const MAX_RUNTIME_MS = 500 * 1000; // Stop gracefully before 540s timeout
    const PAGE_SIZE = 20;
    const now = admin.firestore.Timestamp.now();

    let totalReminders = 0;
    let failedReminders = 0;
    let lastInstituteDoc: admin.firestore.QueryDocumentSnapshot | undefined;

    // Paginate institutes in pages of 20
    let hasMore = true;
    while (hasMore) {
      // Check if we're approaching the timeout
      if (Date.now() - startTime > MAX_RUNTIME_MS) {
        log.warn("Approaching timeout, stopping gracefully", {
          sent: totalReminders,
          failed: failedReminders,
        });
        break;
      }

      let query = db.collection("institutes")
        .orderBy(admin.firestore.FieldPath.documentId())
        .limit(PAGE_SIZE);
      if (lastInstituteDoc) {
        query = query.startAfter(lastInstituteDoc);
      }
      const institutesPage = await query.get();

      if (institutesPage.empty) {
        hasMore = false;
        break;
      }
      lastInstituteDoc = institutesPage.docs[institutesPage.docs.length - 1];
      if (institutesPage.size < PAGE_SIZE) {
        hasMore = false;
      }

      for (const instituteDoc of institutesPage.docs) {
        // Check timeout before each institute
        if (Date.now() - startTime > MAX_RUNTIME_MS) break;

        const institute = instituteDoc.data() as Institute;

        // Check if notifications are enabled
        if (institute.settings?.notificationsEnabled === false) {
          continue;
        }

        // Get overdue invoices
        const overdueInvoicesSnapshot = await db
          .collection("institutes")
          .doc(instituteDoc.id)
          .collection("invoices")
          .where("dueDate", "<", now)
          .where("status", "in", ["pending", "partial"])
          .get();

        for (const invoiceDoc of overdueInvoicesSnapshot.docs) {
          const invoice = invoiceDoc.data() as FeeInvoice;
          const balanceDue = invoice.finalAmount - invoice.paidAmount;

          if (balanceDue <= 0) continue;

          // Get batch name
          const batchDoc = await db
            .collection("institutes")
            .doc(instituteDoc.id)
            .collection("batches")
            .doc(invoice.batchId)
            .get();
          const batchName = batchDoc.exists
            ? (batchDoc.data() as Batch)?.name || "Unknown Batch"
            : "Unknown Batch";

          // Get student details
          const studentDoc = await db
            .collection("institutes")
            .doc(instituteDoc.id)
            .collection("batches")
            .doc(invoice.batchId)
            .collection("students")
            .doc(invoice.studentId)
            .get();

          if (!studentDoc.exists) continue;

          const student = studentDoc.data() as Student;

          if (!student.parentPhone || !isValidPhone(student.parentPhone)) {
            log.warn("Skipping invalid phone for payment reminder", {
              instituteId: instituteDoc.id,
              studentId: invoice.studentId,
              phone: student.parentPhone || "none",
              invoiceId: invoiceDoc.id,
            });
            continue;
          }

          const phoneNumber = formatPhoneNumber(student.parentPhone);

          // Calculate days overdue
          const dueDate = invoice.dueDate.toDate();
          const daysOverdue = Math.floor(
            (now.toDate().getTime() - dueDate.getTime()) / (1000 * 60 * 60 * 24)
          );

          // Format amount
          const formattedAmount = `Rs.${balanceDue.toFixed(0)}`;

          const message =
            `Payment Reminder: ${student.name}'s fee of ${formattedAmount} for ${batchName} ` +
            `is overdue by ${daysOverdue} day${daysOverdue === 1 ? "" : "s"}. ` +
            `Please clear the dues at the earliest. - ${institute.name}`;

          try {
            let result: NotificationResult;

            // Try WhatsApp first
            const twilioClient = getTwilioClient();
            if (twilioClient) {
              result = await sendWhatsAppMessage(twilioClient, phoneNumber, message);

              // Fall back to SMS if WhatsApp fails
              if (!result.success && config.smsProvider === "msg91") {
                result = await sendMsg91Sms(phoneNumber, message);
              }
            } else if (config.smsProvider === "msg91") {
              result = await sendMsg91Sms(phoneNumber, message);
            } else {
              continue;
            }

            if (result.success) {
              totalReminders++;

              // Log the reminder
              await db
                .collection("institutes")
                .doc(instituteDoc.id)
                .collection("paymentReminders")
                .add({
                  invoiceId: invoiceDoc.id,
                  studentId: invoice.studentId,
                  studentName: student.name,
                  amount: balanceDue,
                  daysOverdue,
                  channel: result.channel || "sms",
                  messageSid: result.sid,
                  sentAt: admin.firestore.FieldValue.serverTimestamp(),
                });
            } else {
              failedReminders++;
              log.error("Failed to send payment reminder", {
                instituteId: instituteDoc.id,
                invoiceId: invoiceDoc.id,
                studentId: invoice.studentId,
                error: result.error,
              });
            }
          } catch (error) {
            failedReminders++;
            log.error("Exception sending payment reminder", {
              instituteId: instituteDoc.id,
              invoiceId: invoiceDoc.id,
              error: (error as Error).message,
            });
          }
        }
      }
    }

    log.info("Payment reminder job complete", {
      sent: totalReminders,
      failed: failedReminders,
    });
    return null;
  });

/**
 * Callable function to send a payment reminder for a specific invoice.
 */
export const sendPaymentReminderForInvoice = functions
  .runWith({secrets: [twilioAccountSid, twilioAuthToken, msg91AuthKey]})
  .https.onCall(async (data: {instituteId: string; invoiceId: string}, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Must be authenticated");
    }

    const {instituteId, invoiceId} = data;

    if (!instituteId || !invoiceId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Institute ID and Invoice ID are required"
      );
    }

    // Verify caller has teacher record for this institute
    const teacherDoc = await db.collection("teachers").doc(context.auth.uid).get();
    if (!teacherDoc.exists || teacherDoc.data()?.instituteId !== instituteId) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Not authorized for this institute"
      );
    }

    // Get institute
    const instituteDoc = await db.collection("institutes").doc(instituteId).get();
    if (!instituteDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Institute not found");
    }
    const institute = instituteDoc.data() as Institute;

    // Get invoice
    const invoiceRef = db
      .collection("institutes")
      .doc(instituteId)
      .collection("invoices")
      .doc(invoiceId);
    const invoiceDoc = await invoiceRef.get();

    if (!invoiceDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Invoice not found");
    }
    const invoice = invoiceDoc.data() as FeeInvoice;

    const balanceDue = invoice.finalAmount - invoice.paidAmount;
    if (balanceDue <= 0) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Invoice is already paid"
      );
    }

    // Get batch name
    const batchDoc = await db
      .collection("institutes")
      .doc(instituteId)
      .collection("batches")
      .doc(invoice.batchId)
      .get();
    const batchName = batchDoc.exists
      ? (batchDoc.data() as Batch)?.name || "Unknown Batch"
      : "Unknown Batch";

    // Get student details
    const studentDoc = await db
      .collection("institutes")
      .doc(instituteId)
      .collection("batches")
      .doc(invoice.batchId)
      .collection("students")
      .doc(invoice.studentId)
      .get();

    if (!studentDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Student not found");
    }
    const student = studentDoc.data() as Student;

    if (!student.parentPhone || !isValidPhone(student.parentPhone)) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Student has no valid parent phone number"
      );
    }

    const phoneNumber = formatPhoneNumber(student.parentPhone);

    // Calculate days overdue (if any)
    const now = new Date();
    const dueDate = invoice.dueDate.toDate();
    const daysOverdue = Math.max(
      0,
      Math.floor((now.getTime() - dueDate.getTime()) / (1000 * 60 * 60 * 24))
    );

    const formattedAmount = `Rs.${balanceDue.toFixed(0)}`;
    let message: string;

    if (daysOverdue > 0) {
      message =
        `Payment Reminder: ${student.name}'s fee of ${formattedAmount} for ${batchName} ` +
        `is overdue by ${daysOverdue} day${daysOverdue === 1 ? "" : "s"}. ` +
        `Please clear the dues at the earliest. - ${institute.name}`;
    } else {
      message =
        `Payment Reminder: ${student.name}'s fee of ${formattedAmount} for ${batchName} ` +
        `is due soon. Please make the payment before the due date. - ${institute.name}`;
    }

    let result: NotificationResult;

    // Try WhatsApp first
    const twilioClient = getTwilioClient();
    if (twilioClient) {
      result = await sendWhatsAppMessage(twilioClient, phoneNumber, message);

      // Fall back to SMS if WhatsApp fails
      if (!result.success && config.smsProvider === "msg91") {
        result = await sendMsg91Sms(phoneNumber, message);
      }
    } else if (config.smsProvider === "msg91") {
      result = await sendMsg91Sms(phoneNumber, message);
    } else {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "No notification provider configured"
      );
    }

    if (result.success) {
      // Log the reminder
      await db
        .collection("institutes")
        .doc(instituteId)
        .collection("paymentReminders")
        .add({
          invoiceId,
          studentId: invoice.studentId,
          studentName: student.name,
          amount: balanceDue,
          daysOverdue,
          channel: result.channel || "sms",
          messageSid: result.sid,
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
          manual: true,
        });

      return {success: true, messageSid: result.sid, channel: result.channel};
    } else {
      throw new functions.https.HttpsError(
        "internal",
        result.error || "Failed to send reminder"
      );
    }
  });

// =============================================================================
// PARENT PORTAL - OTP AUTHENTICATION
// =============================================================================

// OTPs stored in Firestore `otps` collection with TTL auto-delete
// Schema: { phoneHash: string, otpHash: string, expiresAt: Timestamp, attempts: number, createdAt: Timestamp }

/**
 * Generate a 6-digit OTP
 */
function generateOtp(): string {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

/**
 * Hash a value with SHA-256
 */
function hashValue(value: string): string {
  return crypto.createHash("sha256").update(value).digest("hex");
}

/**
 * Send OTP to parent phone for verification
 */
export const sendParentOtp = functions
  .runWith({
    secrets: [msg91AuthKey, twilioAccountSid, twilioAuthToken],
    timeoutSeconds: 30,
    memory: "256MB",
  })
  .https.onCall(async (data) => {
    const {phone} = data;

    if (!phone) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Phone number is required"
      );
    }

    // Normalize phone number
    const normalizedPhone = phone.replace(/\D/g, "");
    const fullPhone = normalizedPhone.startsWith("91") ?
      `+${normalizedPhone}` :
      `+91${normalizedPhone}`;

    // Check rate limiting (max 3 OTPs per hour per phone)
    const phoneHash = hashValue(fullPhone);
    const existingOtpDoc = await db.collection("otps").doc(phoneHash).get();
    const existingOtp = existingOtpDoc.exists ? existingOtpDoc.data() : null;
    if (existingOtp && existingOtp.attempts >= 3) {
      throw new functions.https.HttpsError(
        "resource-exhausted",
        "Too many OTP requests. Please try again later."
      );
    }

    // Check if parent exists
    const parentSnapshot = await db
      .collection("parents")
      .where("phone", "==", fullPhone)
      .limit(1)
      .get();

    if (parentSnapshot.empty) {
      throw new functions.https.HttpsError(
        "not-found",
        "No parent account found with this phone number"
      );
    }

    const parent = parentSnapshot.docs[0];
    const parentData = parent.data();

    if (parentData.status !== "active" && parentData.status !== "pending") {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Your account is inactive. Please contact your institute."
      );
    }

    // Generate OTP
    const otp = generateOtp();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes

    // Store hashed OTP in Firestore (Firestore TTL auto-deletes expired docs)
    await db.collection("otps").doc(phoneHash).set({
      otpHash: hashValue(otp),
      expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
      attempts: (existingOtp?.attempts || 0) + 1,
      verifyAttempts: 0,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Send OTP via SMS
    const message = `Your ClassPulse verification code is ${otp}. Valid for 10 minutes. Do not share this code.`;

    let result;
    if (config.smsProvider === "msg91") {
      result = await sendMsg91Sms(fullPhone, message);
    } else {
      const twilioClient = twilio(
        twilioAccountSid.value(),
        twilioAuthToken.value()
      );
      result = await sendTwilioSms(twilioClient, fullPhone, message);
    }

    if (!result.success) {
      throw new functions.https.HttpsError(
        "internal",
        "Failed to send OTP. Please try again."
      );
    }

    // Log OTP request
    await db.collection("otpLogs").add({
      phone: fullPhone,
      type: "parent_login",
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
      channel: result.channel || "sms",
    });

    return {
      success: true,
      message: "OTP sent successfully",
      expiresIn: 600, // seconds
    };
  });

/**
 * Verify OTP and return authentication result
 */
export const verifyParentOtp = functions
  .runWith({
    timeoutSeconds: 30,
    memory: "256MB",
  })
  .https.onCall(async (data) => {
    const {phone, otp} = data;

    if (!phone || !otp) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Phone number and OTP are required"
      );
    }

    // Normalize phone number
    const normalizedPhone = phone.replace(/\D/g, "");
    const fullPhone = normalizedPhone.startsWith("91") ?
      `+${normalizedPhone}` :
      `+91${normalizedPhone}`;

    // Check OTP from Firestore
    const phoneHash = hashValue(fullPhone);
    const otpDocRef = db.collection("otps").doc(phoneHash);
    const otpDoc = await otpDocRef.get();

    if (!otpDoc.exists) {
      throw new functions.https.HttpsError(
        "not-found",
        "No OTP found. Please request a new one."
      );
    }

    const storedOtp = otpDoc.data()!;

    if (storedOtp.expiresAt.toDate() < new Date()) {
      await otpDocRef.delete();
      throw new functions.https.HttpsError(
        "deadline-exceeded",
        "OTP has expired. Please request a new one."
      );
    }

    // Brute force protection: max 5 verify attempts per OTP
    if ((storedOtp.verifyAttempts || 0) >= 5) {
      await otpDocRef.delete();
      throw new functions.https.HttpsError(
        "resource-exhausted",
        "Too many incorrect attempts. Please request a new OTP."
      );
    }

    if (storedOtp.otpHash !== hashValue(otp)) {
      await otpDocRef.update({
        verifyAttempts: admin.firestore.FieldValue.increment(1),
      });
      throw new functions.https.HttpsError(
        "permission-denied",
        "Invalid OTP. Please try again."
      );
    }

    // OTP verified - clear it
    await otpDocRef.delete();

    // Get parent data
    const parentSnapshot = await db
      .collection("parents")
      .where("phone", "==", fullPhone)
      .limit(1)
      .get();

    if (parentSnapshot.empty) {
      throw new functions.https.HttpsError(
        "not-found",
        "Parent account not found"
      );
    }

    const parent = parentSnapshot.docs[0];
    const parentData = parent.data();

    // Update last login and status
    await parent.ref.update({
      lastLoginAt: admin.firestore.FieldValue.serverTimestamp(),
      status: "active",
    });

    // Create a custom token for the parent
    // In production, use Firebase Auth Custom Claims
    const customToken = await admin.auth().createCustomToken(parent.id, {
      isParent: true,
      instituteId: parentData.instituteId,
    });

    return {
      success: true,
      token: customToken,
      parent: {
        id: parent.id,
        phone: parentData.phone,
        name: parentData.name,
        instituteId: parentData.instituteId,
        studentIds: parentData.studentIds,
      },
    };
  });

// =============================================================================
// PARENT PORTAL - LEAVE REQUEST NOTIFICATIONS
// =============================================================================

/**
 * Notify parent when leave request status changes
 */
export const onLeaveRequestUpdate = functions
  .runWith({
    secrets: [msg91AuthKey, twilioAccountSid, twilioAuthToken],
    timeoutSeconds: 60,
    memory: "256MB",
  })
  .firestore.document("leaveRequests/{requestId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    // Only trigger when status changes from pending
    if (before.status === after.status || before.status !== "pending") {
      return null;
    }

    const {parentId, studentId, status, reviewNotes, startDate, endDate} = after;
    const log = createLogger("onLeaveRequestUpdate", {
      instituteId: after.instituteId,
    });

    // Get parent phone
    const parentDoc = await db.collection("parents").doc(parentId).get();
    if (!parentDoc.exists) {
      log.error("Parent not found", {parentId, requestId: context.params.requestId});
      return null;
    }

    const parent = parentDoc.data()!;
    const phone = parent.phone;

    // Get student name using batchId for direct O(1) lookup
    let studentName = "your child";
    try {
      if (after.batchId) {
        const studentDoc = await db
          .collection("institutes")
          .doc(after.instituteId)
          .collection("batches")
          .doc(after.batchId)
          .collection("students")
          .doc(studentId)
          .get();
        if (studentDoc.exists) {
          studentName = studentDoc.data()!.name;
        }
      } else {
        // Fallback: collectionGroup query if batchId missing (legacy data)
        const studentsQuery = await db
          .collectionGroup("students")
          .where(admin.firestore.FieldPath.documentId(), "==", studentId)
          .limit(1)
          .get();
        if (!studentsQuery.empty) {
          studentName = studentsQuery.docs[0].data().name;
        }
      }
    } catch (e) {
      log.error("Error fetching student", {
        studentId,
        requestId: context.params.requestId,
        error: (e as Error).message,
      });
    }

    // Format date range
    const startDateObj = startDate.toDate();
    const endDateObj = endDate.toDate();
    const dateRange = startDateObj.toDateString() === endDateObj.toDateString() ?
      startDateObj.toLocaleDateString("en-IN", {day: "numeric", month: "short"}) :
      `${startDateObj.toLocaleDateString("en-IN", {day: "numeric", month: "short"})} - ${endDateObj.toLocaleDateString("en-IN", {day: "numeric", month: "short"})}`;

    // Build message
    let message = "";
    if (status === "approved") {
      message = `✅ Leave Approved\n\nGood news! The leave request for ${studentName} (${dateRange}) has been approved.`;
    } else if (status === "rejected") {
      message = `❌ Leave Rejected\n\nThe leave request for ${studentName} (${dateRange}) was not approved.`;
    }

    if (reviewNotes) {
      message += `\n\nNote from teacher: ${reviewNotes}`;
    }

    message += "\n\n- ClassPulse";

    // Send notification
    let result;
    if (config.primaryChannel === "whatsapp") {
      const twilioClient = twilio(
        twilioAccountSid.value(),
        twilioAuthToken.value()
      );
      result = await sendWhatsAppMessage(twilioClient, phone, message);

      // Fall back to SMS if WhatsApp fails
      if (!result.success && config.smsProvider === "msg91") {
        result = await sendMsg91Sms(phone, message);
      }
    } else if (config.smsProvider === "msg91") {
      result = await sendMsg91Sms(phone, message);
    }

    // Log the notification
    await db.collection("leaveNotifications").add({
      requestId: context.params.requestId,
      parentId,
      studentId,
      status,
      phone,
      channel: result?.channel || "unknown",
      success: result?.success || false,
      error: result?.error || null,
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return null;
  });
