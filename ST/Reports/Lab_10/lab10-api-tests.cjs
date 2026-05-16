const assert = require("node:assert/strict");
const fs = require("node:fs");
const fsp = require("node:fs/promises");
const path = require("node:path");

const rootDir = path.resolve(__dirname, "..");
const backendDir = path.join(rootDir, "backend");

const apiMethodCaseMatrix = {
  method: "GET /api/admin/users",
  positive: [
    {
      id: "POS-1",
      description: "Valid admin token is provided in Authorization header.",
      expectedStatus: 200,
    },
    {
      id: "POS-2",
      description: "Request contains additional optional headers (Accept, X-Trace-Id).",
      expectedStatus: 200,
    },
  ],
  negative: [
    {
      id: "NEG-1",
      description: "Authorization header is missing.",
      expectedStatus: 403,
    },
    {
      id: "NEG-2",
      description: "Authorization token is invalid or unknown.",
      expectedStatus: 403,
    },
    {
      id: "NEG-3",
      description: "Authenticated non-admin user requests admin endpoint.",
      expectedStatus: 403,
    },
  ],
};

const state = {
  usersById: new Map(),
  usersBySub: new Map(),
  userIdSeq: 1,
  planRuns: [],
  planRunIdSeq: 1,
  pseudoNowTick: 0,
};

const tokenClaims = {
  "admin-token": {
    sub: "auth0|admin-1",
    email: "admin@example.com",
    name: "Admin User",
  },
  "user-a-token": {
    sub: "auth0|user-a",
    email: "user.a@example.com",
    name: "User A",
  },
  "user-b-token": {
    sub: "auth0|user-b",
    email: "user.b@example.com",
    name: "User B",
  },
};

function nowIso() {
  state.pseudoNowTick += 1;
  return new Date(Date.now() + state.pseudoNowTick * 1000).toISOString();
}

function seedUser({ auth0Sub, email, displayName, role }) {
  const user = {
    id: state.userIdSeq,
    auth0Sub,
    email: email || null,
    displayName: displayName || email || null,
    role: role || "user",
    createdAt: nowIso(),
  };

  state.userIdSeq += 1;
  state.usersById.set(user.id, user);
  state.usersBySub.set(user.auth0Sub, user);
  return user;
}

function initState() {
  state.usersById.clear();
  state.usersBySub.clear();
  state.userIdSeq = 1;
  state.planRuns = [];
  state.planRunIdSeq = 1;
  state.pseudoNowTick = 0;

  seedUser({
    auth0Sub: "auth0|admin-1",
    email: "admin@example.com",
    displayName: "Admin User",
    role: "admin",
  });
  seedUser({
    auth0Sub: "auth0|user-a",
    email: "user.a@example.com",
    displayName: "User A",
    role: "user",
  });
  seedUser({
    auth0Sub: "auth0|user-b",
    email: "user.b@example.com",
    displayName: "User B",
    role: "user",
  });
}

function requireModuleWithMocks() {
  const authModulePath = path.join(backendDir, "src", "auth.js");
  const userRepositoryModulePath = path.join(backendDir, "db", "repositories", "userRepository.js");
  const planRepositoryModulePath = path.join(backendDir, "db", "planRepository.js");

  for (const modulePath of [authModulePath, userRepositoryModulePath, planRepositoryModulePath]) {
    const resolved = require.resolve(modulePath);
    delete require.cache[resolved];
  }

  const userRepositoryMockFactory = {
    createUserRepository() {
      return {
        async listUsers() {
          return [...state.usersById.values()]
            .map((user) => ({ ...user, projectCount: state.planRuns.filter((run) => run.userId === user.id).length }))
            .sort((left, right) => right.id - left.id);
        },
        async getUserById(userId) {
          return state.usersById.get(Number(userId)) || null;
        },
        async getUserByAuth0Sub(auth0Sub) {
          return state.usersBySub.get(String(auth0Sub)) || null;
        },
        async upsertFromClaims(claims) {
          const existing = state.usersBySub.get(String(claims?.sub || ""));
          if (existing) {
            if (!existing.email && claims.email) {
              existing.email = String(claims.email);
            }
            if (!existing.displayName && (claims.name || claims.nickname)) {
              existing.displayName = String(claims.name || claims.nickname);
            }
            return existing;
          }

          return seedUser({
            auth0Sub: String(claims.sub),
            email: claims.email ? String(claims.email) : null,
            displayName: claims.name ? String(claims.name) : claims.email ? String(claims.email) : null,
            role: "user",
          });
        },
        async syncProfile(auth0Sub, profile = {}) {
          const existing = state.usersBySub.get(String(auth0Sub));
          const nextEmail = typeof profile.email === "string" ? profile.email.trim() || null : null;
          const nextDisplayName =
            typeof profile.displayName === "string"
              ? profile.displayName.trim() || null
              : typeof profile.name === "string"
                ? profile.name.trim() || null
                : typeof profile.nickname === "string"
                  ? profile.nickname.trim() || null
                  : null;

          if (existing) {
            existing.email = nextEmail || existing.email;
            existing.displayName = nextDisplayName || existing.displayName || existing.email;
            return existing;
          }

          return seedUser({
            auth0Sub: String(auth0Sub),
            email: nextEmail,
            displayName: nextDisplayName || nextEmail || `User ${state.userIdSeq}`,
            role: "user",
          });
        },
        async updateUserDetails(targetUserId, nextProfile = {}) {
          const user = state.usersById.get(Number(targetUserId));
          if (!user) {
            const error = new Error("The requested user could not be found.");
            error.statusCode = 404;
            throw error;
          }

          const hasEmail = Object.prototype.hasOwnProperty.call(nextProfile, "email");
          const hasDisplayName = Object.prototype.hasOwnProperty.call(nextProfile, "displayName");
          const nextEmail = hasEmail ? (typeof nextProfile.email === "string" ? nextProfile.email.trim() : "") : user.email || "";
          const nextDisplayName = hasDisplayName
            ? typeof nextProfile.displayName === "string"
              ? nextProfile.displayName.trim()
              : ""
            : user.displayName || "";

          const resolvedEmail = nextEmail || null;
          const resolvedDisplayName = nextDisplayName || resolvedEmail;

          if (!resolvedEmail && !resolvedDisplayName) {
            const error = new Error("Provide at least an email or a display name for the user.");
            error.statusCode = 400;
            throw error;
          }

          user.email = resolvedEmail;
          user.displayName = resolvedDisplayName;
          return user;
        },
        async updateUserRole(targetUserId, nextRole) {
          const user = state.usersById.get(Number(targetUserId));
          if (!user) {
            const error = new Error("The requested user could not be found.");
            error.statusCode = 404;
            throw error;
          }

          if (nextRole !== "user" && nextRole !== "admin") {
            const error = new Error("User role must be either 'user' or 'admin'.");
            error.statusCode = 400;
            throw error;
          }

          user.role = nextRole;
          return user;
        },
        async deleteUser(targetUserId, actorUserId = null) {
          const user = state.usersById.get(Number(targetUserId));
          if (!user) {
            const error = new Error("The requested user could not be found.");
            error.statusCode = 404;
            throw error;
          }

          if (actorUserId && Number(actorUserId) === Number(targetUserId)) {
            const error = new Error("Admins cannot delete their own account from the admin panel.");
            error.statusCode = 400;
            throw error;
          }

          state.usersById.delete(user.id);
          state.usersBySub.delete(user.auth0Sub);
          state.planRuns = state.planRuns.filter((run) => run.userId !== user.id);
          return user;
        },
      };
    },
  };

  const planRepositoryMockFactory = {
    createPlanRepository() {
      function mapSummary(run) {
        return {
          id: run.id,
          planId: run.planId,
          projectName: run.plan.input?.projectName || "Untitled project",
          summary: run.plan.summary,
          architectureStyle: run.plan.recommendation?.architectureStyle || null,
          deploymentModel: run.plan.recommendation?.deploymentModel || null,
          targetRegion: run.plan.input?.targetRegion || null,
          monthlyEstimate: run.plan.cost?.monthlyEstimate || null,
          createdAt: run.createdAt,
        };
      }

      return {
        async saveGeneratedPlan(userId, plan) {
          const entry = {
            id: state.planRunIdSeq,
            userId: Number(userId),
            planId: String(plan.planId),
            plan,
            createdAt: nowIso(),
          };
          state.planRunIdSeq += 1;
          state.planRuns.push(entry);
          return {
            persisted: true,
            id: entry.id,
            createdAt: entry.createdAt,
            technologies: [],
          };
        },
        async listRecentPlans(userId) {
          return this.listUserPlans(userId, { limit: 10, offset: 0 });
        },
        async listUserPlans(userId, options = {}) {
          const rawLimit = options.limit;
          const rawOffset = options.offset;
          const limit = Number.isInteger(rawLimit) && rawLimit >= 0 ? rawLimit : null;
          const offset = Number.isInteger(rawOffset) && rawOffset >= 0 ? rawOffset : 0;

          const byUser = state.planRuns
            .filter((run) => run.userId === Number(userId))
            .sort((left, right) => right.id - left.id);
          const sliced = limit === null ? byUser.slice(offset) : byUser.slice(offset, offset + limit);

          return sliced.map(mapSummary);
        },
        async getUserPlanByPlanId(userId, planId) {
          const found = state.planRuns.find((run) => run.userId === Number(userId) && run.planId === String(planId));
          if (!found) {
            return null;
          }

          return {
            id: found.id,
            createdAt: found.createdAt,
            plan: {
              ...found.plan,
              technologies: [],
            },
          };
        },
        async deleteUserPlanByPlanId(userId, planId) {
          const index = state.planRuns.findIndex(
            (run) => run.userId === Number(userId) && run.planId === String(planId),
          );
          if (index === -1) {
            return null;
          }

          const [deleted] = state.planRuns.splice(index, 1);
          return {
            id: deleted.id,
            planId: deleted.planId,
            projectName: deleted.plan.input?.projectName || "Untitled project",
          };
        },
      };
    },
  };

  function mockRequireAuth(req, res, next) {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return res.status(403).json({
        error: "Forbidden: missing bearer token.",
      });
    }

    const token = authHeader.slice("Bearer ".length).trim();
    const claims = tokenClaims[token];

    if (!claims) {
      return res.status(403).json({
        error: "Forbidden: invalid bearer token.",
      });
    }

    req.auth = {
      payload: claims,
    };
    return next();
  }

  async function mockAttachCurrentUser(req, res, next) {
    const claims = req.auth?.payload;
    if (!claims?.sub) {
      return res.status(401).json({
        error: "Authenticated token is missing the subject claim.",
      });
    }

    const existing = state.usersBySub.get(claims.sub);
    req.currentUser =
      existing ||
      seedUser({
        auth0Sub: claims.sub,
        email: claims.email || null,
        displayName: claims.name || claims.email || `User ${state.userIdSeq}`,
        role: "user",
      });

    return next();
  }

  function mockRequireAdmin(req, res, next) {
    if (!req.currentUser) {
      return res.status(401).json({
        error: "Current user context is required for admin access.",
      });
    }

    if (req.currentUser.role !== "admin") {
      return res.status(403).json({
        error: "Admin access is required for this route.",
      });
    }

    return next();
  }

  const authExports = {
    attachCurrentUser: mockAttachCurrentUser,
    isAuthConfigured: () => true,
    requireAdmin: mockRequireAdmin,
    requireAuth: mockRequireAuth,
  };

  const authResolved = require.resolve(authModulePath);
  require.cache[authResolved] = {
    id: authResolved,
    filename: authResolved,
    loaded: true,
    exports: authExports,
  };

  const userRepoResolved = require.resolve(userRepositoryModulePath);
  require.cache[userRepoResolved] = {
    id: userRepoResolved,
    filename: userRepoResolved,
    loaded: true,
    exports: userRepositoryMockFactory,
  };

  const planRepoResolved = require.resolve(planRepositoryModulePath);
  require.cache[planRepoResolved] = {
    id: planRepoResolved,
    filename: planRepoResolved,
    loaded: true,
    exports: planRepositoryMockFactory,
  };

  const appPath = path.join(backendDir, "src", "app.js");
  delete require.cache[require.resolve(appPath)];
  const { createApp } = require(appPath);
  return {
    createApp,
  };
}

async function startServer(createApp) {
  const app = createApp();
  const server = await new Promise((resolve) => {
    const running = app.listen(0, "127.0.0.1", () => resolve(running));
  });
  const address = server.address();
  return {
    server,
    baseUrl: `http://127.0.0.1:${address.port}`,
  };
}

async function stopServer(server) {
  if (!server) {
    return;
  }

  await new Promise((resolve, reject) => {
    server.close((error) => {
      if (error) {
        reject(error);
        return;
      }
      resolve();
    });
  });
}

function jsonBody(value) {
  return JSON.stringify(value);
}

async function requestJson(baseUrl, urlPath, options = {}) {
  const response = await fetch(`${baseUrl}${urlPath}`, options);
  const responseText = await response.text();
  let parsedBody = null;
  if (responseText) {
    try {
      parsedBody = JSON.parse(responseText);
    } catch {
      parsedBody = responseText;
    }
  }

  return {
    status: response.status,
    body: parsedBody,
    headers: Object.fromEntries(response.headers.entries()),
  };
}

function authHeaders(token) {
  return {
    Authorization: `Bearer ${token}`,
    "Content-Type": "application/json",
  };
}

function findUserBySub(sub) {
  return state.usersBySub.get(sub) || null;
}

function discoverApiMethods() {
  const appPath = path.join(backendDir, "src", "app.js");
  const appContent = fs.readFileSync(appPath, "utf8");
  const mountRegex = /app\.use\("([^"]+)",\s*([A-Za-z0-9_]+)\);/g;
  const routerMounts = [];
  let mountMatch = null;
  while ((mountMatch = mountRegex.exec(appContent)) !== null) {
    routerMounts.push({
      basePath: mountMatch[1],
      routerVar: mountMatch[2],
    });
  }

  const importRegex = /const\s+([A-Za-z0-9_]+)\s*=\s*require\("\.\/routes\/([A-Za-z0-9_-]+)"\);/g;
  const imports = {};
  let importMatch = null;
  while ((importMatch = importRegex.exec(appContent)) !== null) {
    imports[importMatch[1]] = importMatch[2];
  }

  const methods = [];
  const routeRegex = /router\.(get|post|patch|delete)\("([^"]+)"/g;

  for (const mount of routerMounts) {
    const routeFileName = imports[mount.routerVar];
    if (!routeFileName) {
      continue;
    }

    const routeFilePath = path.join(backendDir, "src", "routes", `${routeFileName}.js`);
    const routeContent = fs.readFileSync(routeFilePath, "utf8");

    let routeMatch = null;
    while ((routeMatch = routeRegex.exec(routeContent)) !== null) {
      const method = routeMatch[1].toUpperCase();
      const routePath = routeMatch[2];
      const normalizedPath = routePath === "/" ? mount.basePath : `${mount.basePath}${routePath}`;
      methods.push({
        method,
        path: normalizedPath,
        source: path.relative(rootDir, routeFilePath).replaceAll("\\", "/"),
      });
    }
  }

  methods.sort((left, right) => {
    const byPath = left.path.localeCompare(right.path);
    if (byPath !== 0) {
      return byPath;
    }
    return left.method.localeCompare(right.method);
  });

  return methods;
}

const samplePlanInput = {
  projectName: "Lab10 CRM",
  projectStage: "mvp",
  businessType: "saas",
  targetRegion: "europe",
  deploymentPreference: "cloud",
  monthlyUsers: 5000,
  monthlyBudget: 1200,
  applicationType: "web-app",
  coreFeatures: ["authentication", "search", "admin-panel"],
  realtimeFeatures: false,
  dataSensitivity: "medium",
  availabilityRequirement: "important",
  expectedGrowth: "moderate",
  teamTechnicalLevel: "medium",
  needFastDelivery: true,
};

async function main() {
  initState();

  const apiMethods = discoverApiMethods();
  const { createApp } = requireModuleWithMocks();
  const { server, baseUrl } = await startServer(createApp);

  const tests = [];

  async function runTest(id, section, description, fn) {
    const startedAt = Date.now();
    try {
      const details = await fn();
      tests.push({
        id,
        section,
        description,
        status: "passed",
        durationMs: Date.now() - startedAt,
        details,
      });
    } catch (error) {
      tests.push({
        id,
        section,
        description,
        status: "failed",
        durationMs: Date.now() - startedAt,
        error: error?.message || String(error),
      });
      throw error;
    }
  }

  let createdUserId = null;

  try {
    await runTest("M01", "module:get-methods", "List available API methods from backend source", async () => {
      assert.ok(apiMethods.length > 0, "Expected non-empty API methods list");
      return {
        totalMethods: apiMethods.length,
      };
    });

    await runTest(
      "M02",
      "module:users-positive-negative",
      "GET /api/admin/users with valid admin token returns list",
      async () => {
        const response = await requestJson(baseUrl, "/api/admin/users", {
          method: "GET",
          headers: authHeaders("admin-token"),
        });
        assert.equal(response.status, 200);
        assert.ok(Array.isArray(response.body.users));
        return {
          httpStatus: response.status,
          usersCount: response.body.users.length,
        };
      },
    );

    await runTest(
      "M03",
      "module:users-positive-negative",
      "GET /api/admin/users without token is forbidden",
      async () => {
        const response = await requestJson(baseUrl, "/api/admin/users", {
          method: "GET",
        });
        assert.equal(response.status, 403);
        return {
          httpStatus: response.status,
          error: response.body?.error || null,
        };
      },
    );

    await runTest(
      "M04",
      "module:users-positive-negative",
      "GET /api/admin/users with non-admin token is forbidden",
      async () => {
        const response = await requestJson(baseUrl, "/api/admin/users", {
          method: "GET",
          headers: authHeaders("user-a-token"),
        });
        assert.equal(response.status, 403);
        return {
          httpStatus: response.status,
          error: response.body?.error || null,
        };
      },
    );

    await runTest("I01", "integration:users-crud", "Create user via PATCH /api/auth/profile", async () => {
      tokenClaims["user-created-token"] = {
        sub: "auth0|crud-created-user",
        email: "created.user@example.com",
        name: "Created User",
      };

      const response = await requestJson(baseUrl, "/api/auth/profile", {
        method: "PATCH",
        headers: {
          Authorization: "Bearer user-created-token",
          "Content-Type": "application/json",
        },
        body: jsonBody({
          email: "created.user@example.com",
          displayName: "Created User",
          name: "Created User",
        }),
      });

      assert.equal(response.status, 200);
      assert.ok(response.body?.user?.id);
      createdUserId = Number(response.body.user.id);
      return {
        httpStatus: response.status,
        createdUserId,
      };
    });

    await runTest("I02", "integration:users-crud", "Read created user via GET /api/admin/users", async () => {
      const response = await requestJson(baseUrl, "/api/admin/users", {
        method: "GET",
        headers: authHeaders("admin-token"),
      });
      assert.equal(response.status, 200);
      const createdUser = response.body.users.find((user) => Number(user.id) === Number(createdUserId));
      assert.ok(createdUser);
      return {
        httpStatus: response.status,
        createdUser,
      };
    });

    await runTest("I03", "integration:users-crud", "Update created user via PATCH /api/admin/users/:id", async () => {
      const response = await requestJson(baseUrl, `/api/admin/users/${createdUserId}`, {
        method: "PATCH",
        headers: authHeaders("admin-token"),
        body: jsonBody({
          email: "created.user+updated@example.com",
          displayName: "Created User Updated",
        }),
      });
      assert.equal(response.status, 200);
      assert.equal(response.body.user.email, "created.user+updated@example.com");
      assert.equal(response.body.user.displayName, "Created User Updated");
      return {
        httpStatus: response.status,
        user: response.body.user,
      };
    });

    await runTest("I04", "integration:users-crud", "Delete created user via DELETE /api/admin/users/:id", async () => {
      const deleteResponse = await requestJson(baseUrl, `/api/admin/users/${createdUserId}`, {
        method: "DELETE",
        headers: authHeaders("admin-token"),
      });
      assert.equal(deleteResponse.status, 200);

      const checkResponse = await requestJson(baseUrl, "/api/admin/users", {
        method: "GET",
        headers: authHeaders("admin-token"),
      });
      const stillExists = checkResponse.body.users.some((user) => Number(user.id) === Number(createdUserId));
      assert.equal(stillExists, false);

      return {
        deleteStatus: deleteResponse.status,
        existsAfterDelete: stillExists,
      };
    });

    await runTest("E01", "errors", "POST /api/plans/generate with empty body returns 400", async () => {
      const response = await requestJson(baseUrl, "/api/plans/generate", {
        method: "POST",
        headers: authHeaders("user-a-token"),
        body: jsonBody({}),
      });
      assert.equal(response.status, 400);
      assert.ok(String(response.body?.error || "").length > 0);
      return {
        httpStatus: response.status,
        error: response.body?.error || null,
      };
    });

    await runTest("E02", "errors", "DELETE request to non-existing endpoint returns 404", async () => {
      const response = await requestJson(baseUrl, "/api/unknown-endpoint", {
        method: "DELETE",
      });
      assert.equal(response.status, 404);
      assert.equal(response.body?.error, "Not found");
      return {
        httpStatus: response.status,
        error: response.body?.error || null,
      };
    });

    await runTest(
      "E03",
      "errors",
      "PATCH /api/admin/users/not-a-number returns validation error 400",
      async () => {
        const response = await requestJson(baseUrl, "/api/admin/users/not-a-number", {
          method: "PATCH",
          headers: authHeaders("admin-token"),
          body: jsonBody({
            email: "x@example.com",
          }),
        });
        assert.equal(response.status, 400);
        assert.ok(String(response.body?.error || "").includes("User id"));
        return {
          httpStatus: response.status,
          error: response.body?.error || null,
        };
      },
    );

    await runTest("A01", "access", "Protected endpoint without token is forbidden", async () => {
      const response = await requestJson(baseUrl, "/api/plans/recent", {
        method: "GET",
      });
      assert.equal(response.status, 403);
      return {
        httpStatus: response.status,
        error: response.body?.error || null,
      };
    });

    await runTest("A02", "access", "User token cannot access admin functions", async () => {
      const response = await requestJson(baseUrl, "/api/admin/users", {
        method: "GET",
        headers: authHeaders("user-a-token"),
      });
      assert.equal(response.status, 403);
      return {
        httpStatus: response.status,
        error: response.body?.error || null,
      };
    });

    await runTest("A03", "access", "User cannot access another user's plan", async () => {
      const createdPlanResponse = await requestJson(baseUrl, "/api/plans/generate", {
        method: "POST",
        headers: authHeaders("user-a-token"),
        body: jsonBody({
          ...samplePlanInput,
          projectName: "Private plan A1",
        }),
      });
      assert.equal(createdPlanResponse.status, 200);
      const planId = createdPlanResponse.body?.plan?.planId;
      assert.ok(planId);

      const getAsAnotherUser = await requestJson(baseUrl, `/api/plans/${planId}`, {
        method: "GET",
        headers: authHeaders("user-b-token"),
      });
      assert.equal(getAsAnotherUser.status, 404);
      return {
        generateStatus: createdPlanResponse.status,
        forbiddenStatus: getAsAnotherUser.status,
        planId,
      };
    });

    await runTest("V01", "validation", "POST /api/plans/generate with missing required field returns 400", async () => {
      const invalidPayload = {
        ...samplePlanInput,
      };
      delete invalidPayload.projectName;

      const response = await requestJson(baseUrl, "/api/plans/generate", {
        method: "POST",
        headers: authHeaders("user-a-token"),
        body: jsonBody(invalidPayload),
      });

      assert.equal(response.status, 400);
      assert.equal(response.body?.error, "Invalid plan input");
      assert.ok(Array.isArray(response.body?.details));
      assert.ok(response.body.details.some((detail) => String(detail).includes("projectName")));
      return {
        httpStatus: response.status,
        details: response.body.details,
      };
    });

    await runTest("V02", "validation", "POST /api/plans/generate with number out of range returns 400", async () => {
      const response = await requestJson(baseUrl, "/api/plans/generate", {
        method: "POST",
        headers: authHeaders("user-a-token"),
        body: jsonBody({
          ...samplePlanInput,
          monthlyBudget: -1,
        }),
      });

      assert.equal(response.status, 400);
      assert.ok(response.body.details.some((detail) => String(detail).includes("monthlyBudget")));
      return {
        httpStatus: response.status,
        details: response.body.details,
      };
    });

    await runTest("V03", "validation", "POST /api/plans/generate with invalid type returns 400", async () => {
      const response = await requestJson(baseUrl, "/api/plans/generate", {
        method: "POST",
        headers: authHeaders("user-a-token"),
        body: jsonBody({
          ...samplePlanInput,
          monthlyUsers: "many users",
        }),
      });

      assert.equal(response.status, 400);
      assert.ok(response.body.details.some((detail) => String(detail).includes("monthlyUsers")));
      return {
        httpStatus: response.status,
        details: response.body.details,
      };
    });

    await runTest(
      "V04",
      "validation",
      "POST /api/plans/generate with very long project name is accepted (no max length validation)",
      async () => {
        const longProjectName = "X".repeat(1024);
        const response = await requestJson(baseUrl, "/api/plans/generate", {
          method: "POST",
          headers: authHeaders("user-a-token"),
          body: jsonBody({
            ...samplePlanInput,
            projectName: longProjectName,
          }),
        });

        assert.equal(response.status, 200);
        return {
          httpStatus: response.status,
          note: "API currently does not enforce maximum length for projectName.",
        };
      },
    );

    await runTest("P01", "pagination", "GET /api/plans with limit/offset returns first page", async () => {
      for (let index = 0; index < 5; index += 1) {
        const generateResponse = await requestJson(baseUrl, "/api/plans/generate", {
          method: "POST",
          headers: authHeaders("user-a-token"),
          body: jsonBody({
            ...samplePlanInput,
            projectName: `Paginated Plan ${index + 1}`,
          }),
        });
        assert.equal(generateResponse.status, 200);
      }

      const response = await requestJson(baseUrl, "/api/plans?limit=2&offset=0", {
        method: "GET",
        headers: authHeaders("user-a-token"),
      });
      assert.equal(response.status, 200);
      assert.ok(Array.isArray(response.body?.plans));
      assert.equal(response.body.plans.length, 2);
      return {
        httpStatus: response.status,
        returnedCount: response.body.plans.length,
      };
    });

    await runTest("P02", "pagination", "GET /api/plans with next offset returns another page", async () => {
      const page1 = await requestJson(baseUrl, "/api/plans?limit=2&offset=0", {
        method: "GET",
        headers: authHeaders("user-a-token"),
      });
      const page2 = await requestJson(baseUrl, "/api/plans?limit=2&offset=2", {
        method: "GET",
        headers: authHeaders("user-a-token"),
      });

      assert.equal(page1.status, 200);
      assert.equal(page2.status, 200);
      assert.equal(page2.body.plans.length, 2);
      assert.notEqual(page1.body.plans[0].planId, page2.body.plans[0].planId);
      return {
        page1FirstPlanId: page1.body.plans[0].planId,
        page2FirstPlanId: page2.body.plans[0].planId,
      };
    });

    await runTest("P03", "pagination", "GET /api/plans with out-of-range offset returns empty array", async () => {
      const response = await requestJson(baseUrl, "/api/plans?limit=10&offset=999", {
        method: "GET",
        headers: authHeaders("user-a-token"),
      });

      assert.equal(response.status, 200);
      assert.ok(Array.isArray(response.body?.plans));
      assert.equal(response.body.plans.length, 0);
      return {
        httpStatus: response.status,
        returnedCount: response.body.plans.length,
      };
    });
  } finally {
    await stopServer(server);
  }

  const summary = {
    generatedAt: new Date().toISOString(),
    total: tests.length,
    passed: tests.filter((entry) => entry.status === "passed").length,
    failed: tests.filter((entry) => entry.status === "failed").length,
  };

  const report = {
    summary,
    apiMethods,
    moduleMethodCaseMatrix: apiMethodCaseMatrix,
    notes: [
      "Protected routes were tested with deterministic mock auth middleware to validate access control scenarios.",
      "Pagination is implemented via limit/offset in this API (not page/limit).",
      "User create endpoint is implemented as PATCH /api/auth/profile for first-time authenticated subject sync.",
    ],
    tests,
  };

  const reportPath = path.join(rootDir, "test", "lab10-report.json");
  await fsp.writeFile(reportPath, JSON.stringify(report, null, 2), "utf8");

  const markdownLines = [];
  markdownLines.push("# Lab 10 API Testing Report");
  markdownLines.push("");
  markdownLines.push(`Generated at: ${report.summary.generatedAt}`);
  markdownLines.push(`Total tests: ${report.summary.total}`);
  markdownLines.push(`Passed: ${report.summary.passed}`);
  markdownLines.push(`Failed: ${report.summary.failed}`);
  markdownLines.push("");
  markdownLines.push("## 1) Available API Methods");
  markdownLines.push("");
  for (const method of apiMethods) {
    markdownLines.push(`- ${method.method} ${method.path} (${method.source})`);
  }
  markdownLines.push("");
  markdownLines.push("## 2) Test Cases for GET /api/admin/users");
  markdownLines.push("");
  markdownLines.push("### Positive");
  for (const item of apiMethodCaseMatrix.positive) {
    markdownLines.push(`- ${item.id}: ${item.description} -> expected ${item.expectedStatus}`);
  }
  markdownLines.push("");
  markdownLines.push("### Negative");
  for (const item of apiMethodCaseMatrix.negative) {
    markdownLines.push(`- ${item.id}: ${item.description} -> expected ${item.expectedStatus}`);
  }
  markdownLines.push("");
  markdownLines.push("## 3-8) Automated Test Execution");
  markdownLines.push("");
  for (const test of tests) {
    const prefix = test.status === "passed" ? "[PASS]" : "[FAIL]";
    markdownLines.push(`- ${prefix} ${test.id} (${test.section}): ${test.description}`);
  }

  const markdownReportPath = path.join(rootDir, "test", "lab10-report.md");
  await fsp.writeFile(markdownReportPath, `${markdownLines.join("\n")}\n`, "utf8");

  if (summary.failed > 0) {
    process.exitCode = 1;
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
