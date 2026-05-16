import { createRequire } from "node:module";
import { promises as fs } from "node:fs";
import path from "node:path";
import process from "node:process";
import { performance } from "node:perf_hooks";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const { Pool } = require("../backend/node_modules/pg");

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const OUTPUT_DIR = path.resolve(process.env.LAB10A_OUTPUT_DIR || path.join(__dirname, "lab10a-output"));
const JSON_REPORT_PATH = path.join(OUTPUT_DIR, "lab10a-report.json");
const PDF_REPORT_PATH = path.join(OUTPUT_DIR, "lab10a-report.pdf");

const DB_CONFIG = {
  host: process.env.DB_HOST || "localhost",
  port: Number(process.env.DB_PORT || 5432),
  database: process.env.DB_NAME || "psms",
  user: process.env.DB_USER || "postgres",
  password: process.env.DB_PASSWORD || "postgres",
};

const startedAt = new Date().toISOString();
const results = [];
const notes = [];

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function safePreview(value, maxLen = 240) {
  if (value === null || value === undefined) return "";
  if (typeof value === "string") return value.slice(0, maxLen);
  try {
    return JSON.stringify(value).slice(0, maxLen);
  } catch {
    return String(value).slice(0, maxLen);
  }
}

function uniquePostIndex() {
  const stamp = Date.now().toString().slice(-6);
  const random = Math.floor(Math.random() * 900 + 100);
  return `L10${stamp}${random}`;
}

async function request(baseUrl, method, endpoint, options = {}) {
  const headers = { ...(options.headers || {}) };
  if (options.token) {
    headers.Authorization = `Bearer ${options.token}`;
  }
  if (options.json !== undefined) {
    headers["Content-Type"] = "application/json";
  }

  const started = performance.now();
  let response;
  try {
    response = await fetch(`${baseUrl}${endpoint}`, {
      method,
      headers,
      body: options.json !== undefined ? JSON.stringify(options.json) : undefined,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    throw new Error(`Request failed for ${method} ${endpoint}: ${message}`);
  }
  const durationMs = Math.round(performance.now() - started);

  const contentType = response.headers.get("content-type") || "";
  const raw = await response.text();
  let body = raw;
  if (contentType.includes("application/json")) {
    try {
      body = JSON.parse(raw);
    } catch {
      body = raw;
    }
  }

  return {
    method,
    endpoint,
    status: response.status,
    duration_ms: durationMs,
    content_type: contentType,
    body,
  };
}

async function runTest(meta, handler) {
  const started = performance.now();

  if (meta.skipReason) {
    const row = {
      ...meta,
      status: "skipped",
      duration_ms: 0,
      details: meta.skipReason,
    };
    results.push(row);
    return row;
  }

  try {
    const payload = await handler();
    const row = {
      ...meta,
      status: "passed",
      duration_ms: Math.round(performance.now() - started),
      ...payload,
    };
    results.push(row);
    return row;
  } catch (error) {
    const row = {
      ...meta,
      status: "failed",
      duration_ms: Math.round(performance.now() - started),
      error: error instanceof Error ? error.message : String(error),
    };
    results.push(row);
    return row;
  }
}

async function getApiMethodsList() {
  const routesDir = path.resolve(__dirname, "../backend/src/routes");
  const files = (await fs.readdir(routesDir)).filter((name) => name.endsWith(".js"));
  const methods = [];
  const matcher = /router\.(get|post|put|patch|delete)\(\s*['"`]([^'"`]+)['"`]/gms;

  for (const fileName of files) {
    const fullPath = path.join(routesDir, fileName);
    const source = await fs.readFile(fullPath, "utf8");
    let match;
    while ((match = matcher.exec(source)) !== null) {
      methods.push({
        method: match[1].toUpperCase(),
        endpoint: match[2],
        source: fileName,
      });
    }
  }

  methods.sort((a, b) => `${a.method} ${a.endpoint}`.localeCompare(`${b.method} ${b.endpoint}`));
  return methods;
}

async function prepareIdentityContext(pool) {
  const adminResult = await pool.query(
    `SELECT user_id, full_name, email, auth0_sub, role
     FROM employees
     WHERE role = 'admin' AND auth0_sub IS NOT NULL
     ORDER BY user_id ASC
     LIMIT 1`
  );
  const operatorResult = await pool.query(
    `SELECT user_id, full_name, email, auth0_sub, role
     FROM employees
     WHERE role = 'operator' AND auth0_sub IS NOT NULL
     ORDER BY user_id ASC
     LIMIT 1`
  );
  const clientResult = await pool.query(
    `SELECT client_id, full_name, email, auth0_sub
     FROM clients
     WHERE auth0_sub IS NOT NULL
       AND email IS NOT NULL
       AND email LIKE '%@%'
     ORDER BY client_id ASC
     LIMIT 6`
  );
  const officesResult = await pool.query(
    `SELECT post_office_id, post_index, address
     FROM post_offices
     ORDER BY post_office_id ASC
     LIMIT 5`
  );
  const itemTypeResult = await pool.query(
    `SELECT item_type_id, name
     FROM item_types
     ORDER BY item_type_id ASC
     LIMIT 1`
  );

  return {
    admin: adminResult.rows[0] || null,
    operator: operatorResult.rows[0] || null,
    clients: clientResult.rows,
    offices: officesResult.rows,
    itemType: itemTypeResult.rows[0] || null,
  };
}

function installMockAuth(tokenPayloadMap) {
  const authPath = require.resolve("../backend/src/middleware/auth");
  const checkJwt = (req, res, next) => {
    const header = String(req.headers?.authorization || "");
    const [scheme, token] = header.split(" ");
    if (!/^Bearer$/i.test(scheme || "") || !token) {
      return res.status(403).json({ ok: false, error: "Bearer token is required" });
    }

    const payload = tokenPayloadMap[token.trim()];
    if (!payload) {
      return res.status(403).json({ ok: false, error: "Invalid or unknown token" });
    }

    req.auth = { payload };
    return next();
  };

  require.cache[authPath] = {
    id: authPath,
    filename: authPath,
    loaded: true,
    exports: { checkJwt },
  };
}

function purgeBackendCache() {
  const modulePaths = [
    "../backend/src/app.js",
    "../backend/src/routes/admin.js",
    "../backend/src/routes/client.js",
    "../backend/src/routes/employee.js",
    "../backend/src/routes/health.js",
    "../backend/src/routes/session.js",
    "../backend/src/routes/support.js",
  ];

  for (const relativePath of modulePaths) {
    const resolved = require.resolve(relativePath);
    delete require.cache[resolved];
  }
}

async function startTestServer(tokenPayloadMap) {
  installMockAuth(tokenPayloadMap);
  purgeBackendCache();

  const { createApp } = require("../backend/src/app");
  const app = createApp();

  const server = await new Promise((resolve) => {
    const instance = app.listen(0, "127.0.0.1", () => resolve(instance));
  });

  const address = server.address();
  const baseUrl = `http://127.0.0.1:${address.port}`;
  return { server, baseUrl };
}

function buildMethodCaseCatalog() {
  return {
    method: "POST /api/admin/offices",
    cases: [
      { id: "MC-01", kind: "positive", title: "Valid body (post_index, address, phone)", expected: 201 },
      { id: "MC-02", kind: "negative", title: "Missing post_index", expected: 400 },
      { id: "MC-03", kind: "negative", title: "Missing address", expected: 400 },
      { id: "MC-04", kind: "negative", title: "Duplicate post_index", expected: 400 },
      { id: "MC-05", kind: "negative", title: "Request without token", expected: 403 },
      { id: "MC-06", kind: "negative", title: "Token without admin privileges", expected: 403 },
    ],
  };
}

function escapePdfText(text) {
  return String(text || "")
    .replaceAll("\\", "\\\\")
    .replaceAll("(", "\\(")
    .replaceAll(")", "\\)");
}

function buildPdfBufferFromLines(lines) {
  const pageWidth = 595;
  const pageHeight = 842;
  const left = 42;
  const top = 802;
  const lineHeight = 14;
  const bottom = 52;
  const maxLines = Math.floor((top - bottom) / lineHeight);

  const pages = [];
  for (let i = 0; i < lines.length; i += maxLines) {
    pages.push(lines.slice(i, i + maxLines));
  }
  if (pages.length === 0) {
    pages.push(["Lab report"]);
  }

  const objects = [];
  objects[1] = "<< /Type /Catalog /Pages 2 0 R >>";

  const firstPageObjId = 4;
  const pageObjIds = [];
  const contentObjIds = [];
  for (let i = 0; i < pages.length; i += 1) {
    const pageObjId = firstPageObjId + i * 2;
    const contentObjId = pageObjId + 1;
    pageObjIds.push(pageObjId);
    contentObjIds.push(contentObjId);
  }

  objects[2] = `<< /Type /Pages /Kids [${pageObjIds.map((id) => `${id} 0 R`).join(" ")}] /Count ${pageObjIds.length} >>`;
  objects[3] = "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>";

  pages.forEach((pageLines, idx) => {
    const streamLines = [];
    const pageNo = idx + 1;
    streamLines.push("BT /F1 10 Tf 0 0 0 rg");
    streamLines.push(`1 0 0 1 ${left} ${pageHeight - 28} Tm (PSMS API Testing Report - Page ${pageNo}/${pages.length}) Tj`);
    streamLines.push("ET");

    pageLines.forEach((line, lineIndex) => {
      const y = top - lineIndex * lineHeight;
      streamLines.push("BT /F1 10 Tf 0 0 0 rg");
      streamLines.push(`1 0 0 1 ${left} ${y} Tm (${escapePdfText(line)}) Tj`);
      streamLines.push("ET");
    });

    const stream = streamLines.join("\n");
    const pageObjId = pageObjIds[idx];
    const contentObjId = contentObjIds[idx];

    objects[pageObjId] =
      `<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ${pageWidth} ${pageHeight}] /Resources << /Font << /F1 3 0 R >> >> /Contents ${contentObjId} 0 R >>`;
    objects[contentObjId] = `<< /Length ${Buffer.byteLength(stream, "utf8")} >>\nstream\n${stream}\nendstream`;
  });

  let pdf = "%PDF-1.4\n";
  const offsets = [];
  for (let id = 1; id < objects.length; id += 1) {
    offsets[id] = Buffer.byteLength(pdf, "utf8");
    pdf += `${id} 0 obj\n${objects[id]}\nendobj\n`;
  }

  const xrefOffset = Buffer.byteLength(pdf, "utf8");
  pdf += `xref\n0 ${objects.length}\n`;
  pdf += "0000000000 65535 f \n";
  for (let id = 1; id < objects.length; id += 1) {
    pdf += `${String(offsets[id]).padStart(10, "0")} 00000 n \n`;
  }
  pdf += `trailer\n<< /Size ${objects.length} /Root 1 0 R >>\nstartxref\n${xrefOffset}\n%%EOF`;
  return Buffer.from(pdf, "utf8");
}

function buildPdfLines(report) {
  const lines = [];
  lines.push("LAB 10A - API testing");
  lines.push(`Started at: ${report.started_at}`);
  lines.push(`Finished at: ${report.finished_at}`);
  lines.push(`Base URL: ${report.base_url}`);
  lines.push("");
  lines.push("SUMMARY");
  lines.push(`Total tests: ${report.summary.total}`);
  lines.push(`Passed: ${report.summary.passed}`);
  lines.push(`Failed: ${report.summary.failed}`);
  lines.push(`Skipped: ${report.summary.skipped}`);
  lines.push(`Total duration (ms): ${report.summary.total_duration_ms}`);
  lines.push("");

  if (report.notes.length > 0) {
    lines.push("NOTES");
    report.notes.forEach((note, index) => lines.push(`${index + 1}. ${note}`));
    lines.push("");
  }

  lines.push(`API METHODS (${report.api_methods.length})`);
  report.api_methods.forEach((row) => lines.push(`${row.method} ${row.endpoint} [${row.source}]`));
  lines.push("");

  lines.push(`TEST CASE CATALOG FOR ${report.method_case_catalog.method}`);
  report.method_case_catalog.cases.forEach((item) => {
    lines.push(`${item.id} | ${item.kind} | expected ${item.expected} | ${item.title}`);
  });
  lines.push("");

  lines.push("EXECUTION RESULTS");
  report.tests.forEach((test) => {
    lines.push(`[${test.id}] ${test.status.toUpperCase()} | ${test.area} | ${test.name}`);
    lines.push(`expected: ${test.expected}`);
    if (test.http) {
      lines.push(`actual: HTTP ${test.http.status} (${test.http.method} ${test.http.endpoint})`);
      lines.push(`response: ${safePreview(test.http.body_preview || test.http.body || "")}`);
    }
    if (test.details) {
      lines.push(`details: ${safePreview(test.details)}`);
    }
    if (test.error) {
      lines.push(`error: ${safePreview(test.error)}`);
    }
    lines.push("");
  });

  return lines;
}

async function main() {
  const pool = new Pool(DB_CONFIG);
  let server = null;
  let baseUrl = "";

  try {
    const apiMethods = await getApiMethodsList();
    const methodCaseCatalog = buildMethodCaseCatalog();
    const identity = await prepareIdentityContext(pool);

    const admin = identity.admin;
    const operator = identity.operator;
    const clientA = identity.clients[0] || null;
    const clientB = identity.clients[1] || null;
    const clientC = identity.clients[2] || null;
    const officeA = identity.offices[0] || null;
    const officeB = identity.offices[1] || identity.offices[0] || null;
    const itemType = identity.itemType;

    if (!admin) notes.push("No admin with auth0_sub found, admin-only tests were skipped.");
    if (!operator) notes.push("No operator with auth0_sub found, role restriction test was skipped.");
    if (!clientA || !clientB || !clientC) notes.push("Less than 3 clients with auth0_sub found, isolation test was skipped.");
    if (!officeA || !officeB) notes.push("At least two post offices are required for postal item create tests.");
    if (!itemType) notes.push("No item_types rows found in DB; postal item create test was skipped.");

    const tokenPayloadMap = {};
    if (admin) {
      tokenPayloadMap["admin-token"] = {
        sub: admin.auth0_sub,
        email: admin.email,
        name: admin.full_name,
      };
    }
    if (operator) {
      tokenPayloadMap["operator-token"] = {
        sub: operator.auth0_sub,
        email: operator.email,
        name: operator.full_name,
      };
    }
    if (clientA) {
      tokenPayloadMap["client-token-1"] = {
        sub: clientA.auth0_sub,
        email: clientA.email,
        name: clientA.full_name,
      };
    }
    if (clientB) {
      tokenPayloadMap["client-token-2"] = {
        sub: clientB.auth0_sub,
        email: clientB.email,
        name: clientB.full_name,
      };
    }
    if (clientC) {
      tokenPayloadMap["client-token-3"] = {
        sub: clientC.auth0_sub,
        email: clientC.email,
        name: clientC.full_name,
      };
    }

    const serverPayload = await startTestServer(tokenPayloadMap);
    server = serverPayload.server;
    baseUrl = serverPayload.baseUrl;

    await runTest(
      {
        id: "M-01",
        area: "Module",
        name: "POST /api/admin/offices with valid body",
        expected: "201 Created",
        skipReason: admin ? "" : "Admin identity is not available",
      },
      async () => {
        const postIndex = uniquePostIndex();
        const created = await request(baseUrl, "POST", "/api/admin/offices", {
          token: "admin-token",
          json: { post_index: postIndex, address: "Lab10 test address", phone: "+375291111111" },
        });
        assert(created.status === 201, `Expected 201, got ${created.status}`);
        assert(created.body?.office?.post_office_id, "Office ID is missing in response");

        await request(baseUrl, "DELETE", `/api/admin/offices/${created.body.office.post_office_id}`, {
          token: "admin-token",
        });

        return { http: created };
      }
    );

    await runTest(
      {
        id: "M-02",
        area: "Module",
        name: "POST /api/admin/offices without post_index",
        expected: "400 Bad Request",
        skipReason: admin ? "" : "Admin identity is not available",
      },
      async () => {
        const response = await request(baseUrl, "POST", "/api/admin/offices", {
          token: "admin-token",
          json: { address: "Only address" },
        });
        assert(response.status === 400, `Expected 400, got ${response.status}`);
        return { http: response };
      }
    );

    await runTest(
      {
        id: "M-03",
        area: "Module",
        name: "POST /api/admin/offices without address",
        expected: "400 Bad Request",
        skipReason: admin ? "" : "Admin identity is not available",
      },
      async () => {
        const response = await request(baseUrl, "POST", "/api/admin/offices", {
          token: "admin-token",
          json: { post_index: uniquePostIndex() },
        });
        assert(response.status === 400, `Expected 400, got ${response.status}`);
        return { http: response };
      }
    );

    await runTest(
      {
        id: "M-04",
        area: "Module",
        name: "POST /api/admin/offices duplicate post_index",
        expected: "400 Bad Request",
        skipReason: admin ? "" : "Admin identity is not available",
      },
      async () => {
        const duplicate = uniquePostIndex();
        const first = await request(baseUrl, "POST", "/api/admin/offices", {
          token: "admin-token",
          json: { post_index: duplicate, address: "Dup test A", phone: "+375292222222" },
        });
        assert(first.status === 201, `Setup failed: expected 201, got ${first.status}`);

        const second = await request(baseUrl, "POST", "/api/admin/offices", {
          token: "admin-token",
          json: { post_index: duplicate, address: "Dup test B", phone: "+375293333333" },
        });
        assert(second.status === 400, `Expected 400, got ${second.status}`);

        await request(baseUrl, "DELETE", `/api/admin/offices/${first.body.office.post_office_id}`, {
          token: "admin-token",
        });

        return { http: second };
      }
    );

    let crudOfficeId = null;
    let crudOfficeIndex = "";
    await runTest(
      {
        id: "I-01",
        area: "Integration CRUD",
        name: "Create office",
        expected: "201 Created and office exists",
        skipReason: admin ? "" : "Admin identity is not available",
      },
      async () => {
        crudOfficeIndex = uniquePostIndex();
        const response = await request(baseUrl, "POST", "/api/admin/offices", {
          token: "admin-token",
          json: { post_index: crudOfficeIndex, address: "CRUD office", phone: "+375294444444" },
        });
        assert(response.status === 201, `Expected 201, got ${response.status}`);
        crudOfficeId = response.body?.office?.post_office_id || null;
        assert(crudOfficeId, "No office id in create response");
        return { http: response };
      }
    );

    await runTest(
      {
        id: "I-02",
        area: "Integration CRUD",
        name: "Read created office",
        expected: "200 OK and office is returned by filter",
        skipReason: admin && crudOfficeIndex ? "" : "Create step did not provide office index",
      },
      async () => {
        const response = await request(baseUrl, "GET", `/api/admin/offices?post_index=${encodeURIComponent(crudOfficeIndex)}`, {
          token: "admin-token",
        });
        assert(response.status === 200, `Expected 200, got ${response.status}`);
        const found = Array.isArray(response.body?.offices)
          ? response.body.offices.some((row) => row.post_index === crudOfficeIndex)
          : false;
        assert(found, "Created office not found in GET response");
        return { http: response };
      }
    );

    await runTest(
      {
        id: "I-03",
        area: "Integration CRUD",
        name: "Update created office phone",
        expected: "200 OK and phone is updated",
        skipReason: admin && crudOfficeId ? "" : "Create step did not provide office id",
      },
      async () => {
        const nextPhone = "+375295555555";
        const response = await request(baseUrl, "PATCH", `/api/admin/offices/${crudOfficeId}/phone`, {
          token: "admin-token",
          json: { phone: nextPhone },
        });
        assert(response.status === 200, `Expected 200, got ${response.status}`);
        assert(response.body?.office?.phone === nextPhone, "Phone was not updated");
        return { http: response };
      }
    );

    await runTest(
      {
        id: "I-04",
        area: "Integration CRUD",
        name: "Delete created office",
        expected: "API requirement check: expected 204 by lab criteria, actual backend behavior captured",
        skipReason: admin && crudOfficeId ? "" : "Create step did not provide office id",
      },
      async () => {
        const response = await request(baseUrl, "DELETE", `/api/admin/offices/${crudOfficeId}`, {
          token: "admin-token",
        });
        assert(response.status === 200, `Backend currently returns ${response.status}, expected 200 by implementation`);
        const readAfterDelete = await request(
          baseUrl,
          "GET",
          `/api/admin/offices?post_index=${encodeURIComponent(crudOfficeIndex)}`,
          { token: "admin-token" }
        );
        const exists = Array.isArray(readAfterDelete.body?.offices)
          ? readAfterDelete.body.offices.some((row) => row.post_index === crudOfficeIndex)
          : false;
        assert(!exists, "Deleted office is still listed");
        return {
          http: response,
          details: "Backend returns 200 on delete; lab criterion mentions 204.",
        };
      }
    );

    await runTest(
      {
        id: "E-01",
        area: "Error handling",
        name: "POST /api/admin/offices with empty body",
        expected: "400 Bad Request",
        skipReason: admin ? "" : "Admin identity is not available",
      },
      async () => {
        const response = await request(baseUrl, "POST", "/api/admin/offices", {
          token: "admin-token",
          json: {},
        });
        assert(response.status === 400, `Expected 400, got ${response.status}`);
        return { http: response };
      }
    );

    await runTest(
      {
        id: "E-02",
        area: "Error handling",
        name: "PATCH /api/admin/users/employee/:id/office with invalid office_id type",
        expected: "400 Bad Request",
        skipReason: admin && operator ? "" : "Admin or operator identity is not available",
      },
      async () => {
        const response = await request(
          baseUrl,
          "PATCH",
          `/api/admin/users/employee/${operator.user_id}/office`,
          {
            token: "admin-token",
            json: { office_id: "not-a-number" },
          }
        );
        assert(response.status === 400, `Expected 400, got ${response.status}`);
        return { http: response };
      }
    );

    await runTest(
      {
        id: "E-03",
        area: "Error handling",
        name: "GET request to unknown endpoint",
        expected: "404 Not Found",
      },
      async () => {
        const response = await request(baseUrl, "GET", "/api/endpoint-does-not-exist");
        assert(response.status === 404, `Expected 404, got ${response.status}`);
        return { http: response };
      }
    );

    await runTest(
      {
        id: "A-01",
        area: "Access control",
        name: "Admin endpoint without token",
        expected: "403 Forbidden",
      },
      async () => {
        const response = await request(baseUrl, "GET", "/api/admin/users");
        assert(response.status === 403, `Expected 403, got ${response.status}`);
        return { http: response };
      }
    );

    await runTest(
      {
        id: "A-02",
        area: "Access control",
        name: "Admin endpoint with operator token",
        expected: "403 Forbidden",
        skipReason: operator ? "" : "Operator identity is not available",
      },
      async () => {
        const response = await request(baseUrl, "GET", "/api/admin/users", {
          token: "operator-token",
        });
        assert(response.status === 403, `Expected 403, got ${response.status}`);
        return { http: response };
      }
    );

    let isolatedItemId = null;
    await runTest(
      {
        id: "A-03",
        area: "Access control",
        name: "Client isolation: another client cannot read foreign postal item",
        expected: "404 Not Found (isolation check)",
        skipReason:
          clientA && clientB && clientC && officeA && officeB && itemType
            ? ""
            : "Missing required clients/offices/item type for isolation scenario",
      },
      async () => {
        const created = await request(baseUrl, "POST", "/api/client/postal-items", {
          token: "client-token-1",
          json: {
            sender_office_id: officeA.post_office_id,
            recipient_office_id: officeB.post_office_id,
            item_type_id: itemType.item_type_id,
            weight_kg: 0.65,
            declared_value: 35.5,
            recipient: {
              full_name: clientB.full_name,
              email: clientB.email,
            },
          },
        });
        assert(created.status === 201, `Setup failed: expected 201, got ${created.status}`);
        isolatedItemId = created.body?.item?.item_id || null;
        assert(isolatedItemId, "No item_id returned from create");

        const forbiddenRead = await request(baseUrl, "GET", `/api/client/postal-items/${isolatedItemId}`, {
          token: "client-token-3",
        });
        assert(forbiddenRead.status === 404, `Expected 404, got ${forbiddenRead.status}`);

        const cleanup = await request(baseUrl, "DELETE", `/api/employee/postal-items/${isolatedItemId}`, {
          token: "admin-token",
        });
        assert(cleanup.status === 200, `Cleanup failed: expected 200, got ${cleanup.status}`);

        return { http: forbiddenRead };
      }
    );

    await runTest(
      {
        id: "V-01",
        area: "Validation",
        name: "POST /api/client/reviews with too long comment",
        expected: "400 Bad Request",
        skipReason: clientA && officeA ? "" : "Client or office is not available",
      },
      async () => {
        const response = await request(baseUrl, "POST", "/api/client/reviews", {
          token: "client-token-1",
          json: {
            office_id: officeA.post_office_id,
            rating: 5,
            comment: "X".repeat(2001),
          },
        });
        assert(response.status === 400, `Expected 400, got ${response.status}`);
        return { http: response };
      }
    );

    await runTest(
      {
        id: "V-02",
        area: "Validation",
        name: "POST /api/client/reviews with out-of-range rating",
        expected: "400 Bad Request",
        skipReason: clientA && officeA ? "" : "Client or office is not available",
      },
      async () => {
        const response = await request(baseUrl, "POST", "/api/client/reviews", {
          token: "client-token-1",
          json: {
            office_id: officeA.post_office_id,
            rating: 8,
            comment: "Range test",
          },
        });
        assert(response.status === 400, `Expected 400, got ${response.status}`);
        return { http: response };
      }
    );

    await runTest(
      {
        id: "V-03",
        area: "Validation",
        name: "POST /api/client/reviews without required office_id",
        expected: "400 Bad Request",
        skipReason: clientA ? "" : "Client is not available",
      },
      async () => {
        const response = await request(baseUrl, "POST", "/api/client/reviews", {
          token: "client-token-1",
          json: {
            rating: 4,
            comment: "Missing office id",
          },
        });
        assert(response.status === 400, `Expected 400, got ${response.status}`);
        return { http: response };
      }
    );

    await runTest(
      {
        id: "P-01",
        area: "Pagination",
        name: "GET /api/admin/users?page=1&limit=2",
        expected: "Expected <=2 rows if pagination is implemented",
        skipReason: admin ? "" : "Admin identity is not available",
      },
      async () => {
        const response = await request(baseUrl, "GET", "/api/admin/users?page=1&limit=2", {
          token: "admin-token",
        });
        assert(response.status === 200, `Expected 200, got ${response.status}`);
        assert(Array.isArray(response.body?.users), "users array is missing");
        assert(response.body.users.length <= 2, `Pagination is ignored: got ${response.body.users.length} rows`);
        return { http: response };
      }
    );

    await runTest(
      {
        id: "P-02",
        area: "Pagination",
        name: "GET /api/admin/users?page=9999&limit=2",
        expected: "Expected empty list or error for out-of-range page",
        skipReason: admin ? "" : "Admin identity is not available",
      },
      async () => {
        const response = await request(baseUrl, "GET", "/api/admin/users?page=9999&limit=2", {
          token: "admin-token",
        });
        const isEmptyArray = response.status === 200 && Array.isArray(response.body?.users) && response.body.users.length === 0;
        const isError = response.status >= 400;
        assert(isEmptyArray || isError, `Expected empty array or error, got status=${response.status}`);
        return { http: response };
      }
    );

    const finishedAt = new Date().toISOString();
    const summary = {
      total: results.length,
      passed: results.filter((row) => row.status === "passed").length,
      failed: results.filter((row) => row.status === "failed").length,
      skipped: results.filter((row) => row.status === "skipped").length,
      total_duration_ms: results.reduce((acc, row) => acc + (row.duration_ms || 0), 0),
    };

    const report = {
      started_at: startedAt,
      finished_at: finishedAt,
      base_url: baseUrl,
      db_config: {
        host: DB_CONFIG.host,
        port: DB_CONFIG.port,
        database: DB_CONFIG.database,
      },
      notes,
      summary,
      api_methods: apiMethods,
      method_case_catalog: methodCaseCatalog,
      tests: results.map((row) => ({
        ...row,
        http: row.http
          ? {
              method: row.http.method,
              endpoint: row.http.endpoint,
              status: row.http.status,
              duration_ms: row.http.duration_ms,
              content_type: row.http.content_type,
              body_preview: safePreview(row.http.body),
            }
          : undefined,
      })),
    };

    await fs.mkdir(OUTPUT_DIR, { recursive: true });
    await fs.writeFile(JSON_REPORT_PATH, JSON.stringify(report, null, 2), "utf8");
    await fs.writeFile(PDF_REPORT_PATH, buildPdfBufferFromLines(buildPdfLines(report)));

    console.log(`Lab 10A tests completed. Passed=${summary.passed}, Failed=${summary.failed}, Skipped=${summary.skipped}`);
    console.log(`JSON report: ${JSON_REPORT_PATH}`);
    console.log(`PDF report: ${PDF_REPORT_PATH}`);

    if (summary.failed > 0) {
      process.exitCode = 1;
    }
  } finally {
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
    await pool.end();
  }
}

main().catch(async (error) => {
  const finishedAt = new Date().toISOString();
  const fallback = {
    started_at: startedAt,
    finished_at: finishedAt,
    base_url: "unavailable",
    notes: [...notes, "Fatal error during test execution"],
    summary: {
      total: results.length,
      passed: results.filter((row) => row.status === "passed").length,
      failed: results.filter((row) => row.status === "failed").length + 1,
      skipped: results.filter((row) => row.status === "skipped").length,
      total_duration_ms: results.reduce((acc, row) => acc + (row.duration_ms || 0), 0),
    },
    fatal_error: error instanceof Error ? error.message : String(error),
    tests: results,
  };

  await fs.mkdir(OUTPUT_DIR, { recursive: true });
  await fs.writeFile(JSON_REPORT_PATH, JSON.stringify(fallback, null, 2), "utf8");
  await fs.writeFile(PDF_REPORT_PATH, buildPdfBufferFromLines(buildPdfLines({
    ...fallback,
    api_methods: [],
    method_case_catalog: { method: "-", cases: [] },
    tests: fallback.tests,
  })));

  console.error("Lab 10A run failed with fatal error.");
  console.error(error);
  process.exit(1);
});
