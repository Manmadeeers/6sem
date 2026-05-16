const test = require("node:test");
const assert = require("node:assert/strict");

const { DEFAULT_ENGINE_SETTINGS } = require("../../engine/engineSettings");
const { generatePlan, normalizeInput, validateInput } = require("../../engine/planEngine");

function createValidInput(overrides = {}) {
  return {
    projectName: "Acme Platform",
    projectStage: "idea",
    businessType: "saas",
    targetRegion: "north-america",
    deploymentPreference: "cloud",
    monthlyUsers: 800,
    monthlyBudget: 300,
    applicationType: "web-app",
    coreFeatures: ["authentication", "file-upload"],
    realtimeFeatures: false,
    dataSensitivity: "low",
    availabilityRequirement: "basic",
    expectedGrowth: "slow",
    teamTechnicalLevel: "medium",
    needFastDelivery: false,
    ...overrides,
  };
}

test("normalizeInput trims text and coerces primitive types", () => {
  const normalized = normalizeInput({
    projectName: "  Demo App  ",
    monthlyUsers: "1200",
    monthlyBudget: "450",
    realtimeFeatures: 1,
    needFastDelivery: 0,
    coreFeatures: ["authentication", 42],
  });

  assert.equal(normalized.projectName, "Demo App");
  assert.equal(normalized.monthlyUsers, 1200);
  assert.equal(normalized.monthlyBudget, 450);
  assert.equal(normalized.realtimeFeatures, true);
  assert.equal(normalized.needFastDelivery, false);
  assert.deepEqual(normalized.coreFeatures, ["authentication", "42"]);
});

test("validateInput throws 400 with details for invalid payload", () => {
  const invalidInput = {
    ...createValidInput(),
    projectName: "",
    projectStage: "unknown-stage",
    monthlyUsers: -5,
    coreFeatures: ["authentication", "bad-feature"],
    realtimeFeatures: "yes",
  };

  assert.throws(
    () => validateInput(invalidInput),
    (error) => {
      assert.equal(error.statusCode, 400);
      assert.equal(error.message, "Invalid plan input");
      assert.ok(Array.isArray(error.details));
      assert.ok(error.details.some((detail) => detail.includes("projectName is required")));
      assert.ok(error.details.some((detail) => detail.includes("projectStage must be one of")));
      assert.ok(error.details.some((detail) => detail.includes("monthlyUsers must be a valid number")));
      assert.ok(error.details.some((detail) => detail.includes("coreFeatures contains unsupported values")));
      assert.ok(error.details.some((detail) => detail.includes("realtimeFeatures must be true or false")));
      return true;
    },
  );
});

test("generatePlan builds deterministic planId when Date.now and Math.random are stubbed", () => {
  const originalNow = Date.now;
  const originalRandom = Math.random;
  const fixedNow = 1710000000000;
  const fixedRandom = 0.123456789;

  Date.now = () => fixedNow;
  Math.random = () => fixedRandom;

  try {
    const plan = generatePlan(createValidInput());
    const expectedId = `acme-platform-${fixedNow.toString(36)}-${fixedRandom.toString(36).slice(2, 8)}`;

    assert.equal(plan.planId, expectedId);
    assert.equal(plan.generatedAt.endsWith("Z"), true);
  } finally {
    Date.now = originalNow;
    Math.random = originalRandom;
  }
});

test("generatePlan appends roadmap steps for idea stage, file uploads and realtime", () => {
  const plan = generatePlan(
    createValidInput({
      projectStage: "idea",
      coreFeatures: ["file-upload"],
      realtimeFeatures: true,
    }),
  );

  assert.ok(
    plan.roadmap.includes(
      "Validate the MVP with one deployment environment before investing in advanced infrastructure.",
    ),
  );
  assert.ok(
    plan.roadmap.includes(
      "Add storage lifecycle policies when user-generated content volume starts growing.",
    ),
  );
  assert.ok(
    plan.roadmap.includes(
      "Stress-test realtime traffic and move stateful communication behind dedicated gateways as usage increases.",
    ),
  );
});

test("generatePlan applies region multiplier overrides from engine settings", () => {
  const plan = generatePlan(
    createValidInput({ targetRegion: "europe" }),
    {
      ...DEFAULT_ENGINE_SETTINGS,
      regionMultipliers: {
        ...DEFAULT_ENGINE_SETTINGS.regionMultipliers,
        europe: 1.6,
      },
    },
  );

  assert.equal(plan.regionProfile.code, "europe");
  assert.equal(plan.regionProfile.costMultiplier, 1.6);
  assert.equal(plan.recommendation.regionAdjustments.costMultiplier, 1.6);
  assert.ok(plan.cost.assumptions.some((line) => line.includes("1.6")));
});

test("generatePlan keeps recommended components unique", () => {
  const plan = generatePlan(
    createValidInput({
      targetRegion: "global",
      coreFeatures: ["file-upload"],
    }),
  );

  const cdnCount = plan.recommendation.components.filter((component) => component === "cdn").length;
  assert.equal(cdnCount, 1);
});
