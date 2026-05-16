# Lab 10 API Testing Report

Generated at: 2026-05-16T08:45:23.601Z
Total tests: 21
Passed: 21
Failed: 0

## 1) Available API Methods

- GET /api/admin/analytics/overview (backend/src/routes/admin.js)
- GET /api/admin/reports/analytics.pdf (backend/src/routes/admin.js)
- GET /api/admin/settings/engine (backend/src/routes/admin.js)
- PATCH /api/admin/settings/engine (backend/src/routes/admin.js)
- GET /api/admin/technologies (backend/src/routes/admin.js)
- POST /api/admin/technologies (backend/src/routes/admin.js)
- DELETE /api/admin/technologies/:technologyId (backend/src/routes/admin.js)
- PATCH /api/admin/technologies/:technologyId (backend/src/routes/admin.js)
- GET /api/admin/technology-categories (backend/src/routes/admin.js)
- GET /api/admin/users (backend/src/routes/admin.js)
- DELETE /api/admin/users/:userId (backend/src/routes/admin.js)
- PATCH /api/admin/users/:userId (backend/src/routes/admin.js)
- PATCH /api/admin/users/:userId/role (backend/src/routes/admin.js)
- GET /api/auth/me (backend/src/routes/auth.js)
- PATCH /api/auth/profile (backend/src/routes/auth.js)
- GET /api/health (backend/src/routes/health.js)
- GET /api/plans (backend/src/routes/plans.js)
- DELETE /api/plans/:planId (backend/src/routes/plans.js)
- GET /api/plans/:planId (backend/src/routes/plans.js)
- POST /api/plans/generate (backend/src/routes/plans.js)
- GET /api/plans/recent (backend/src/routes/plans.js)
- GET /api/questionnaire (backend/src/routes/questionnaire.js)

## 2) Test Cases for GET /api/admin/users

### Positive
- POS-1: Valid admin token is provided in Authorization header. -> expected 200
- POS-2: Request contains additional optional headers (Accept, X-Trace-Id). -> expected 200

### Negative
- NEG-1: Authorization header is missing. -> expected 403
- NEG-2: Authorization token is invalid or unknown. -> expected 403
- NEG-3: Authenticated non-admin user requests admin endpoint. -> expected 403

## 3-8) Automated Test Execution

- [PASS] M01 (module:get-methods): List available API methods from backend source
- [PASS] M02 (module:users-positive-negative): GET /api/admin/users with valid admin token returns list
- [PASS] M03 (module:users-positive-negative): GET /api/admin/users without token is forbidden
- [PASS] M04 (module:users-positive-negative): GET /api/admin/users with non-admin token is forbidden
- [PASS] I01 (integration:users-crud): Create user via PATCH /api/auth/profile
- [PASS] I02 (integration:users-crud): Read created user via GET /api/admin/users
- [PASS] I03 (integration:users-crud): Update created user via PATCH /api/admin/users/:id
- [PASS] I04 (integration:users-crud): Delete created user via DELETE /api/admin/users/:id
- [PASS] E01 (errors): POST /api/plans/generate with empty body returns 400
- [PASS] E02 (errors): DELETE request to non-existing endpoint returns 404
- [PASS] E03 (errors): PATCH /api/admin/users/not-a-number returns validation error 400
- [PASS] A01 (access): Protected endpoint without token is forbidden
- [PASS] A02 (access): User token cannot access admin functions
- [PASS] A03 (access): User cannot access another user's plan
- [PASS] V01 (validation): POST /api/plans/generate with missing required field returns 400
- [PASS] V02 (validation): POST /api/plans/generate with number out of range returns 400
- [PASS] V03 (validation): POST /api/plans/generate with invalid type returns 400
- [PASS] V04 (validation): POST /api/plans/generate with very long project name is accepted (no max length validation)
- [PASS] P01 (pagination): GET /api/plans with limit/offset returns first page
- [PASS] P02 (pagination): GET /api/plans with next offset returns another page
- [PASS] P03 (pagination): GET /api/plans with out-of-range offset returns empty array
