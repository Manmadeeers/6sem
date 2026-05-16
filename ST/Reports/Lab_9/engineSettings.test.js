const test = require("node:test");
const assert = require("node:assert/strict");

const { DEFAULT_ENGINE_SETTINGS, normalizeEngineSettings } = require("../../engine/engineSettings");

test("normalizeEngineSettings keeps valid custom values", () => {
  const normalized = normalizeEngineSettings({
    regionMultipliers: {
      "north-america": 1.05,
      europe: 1.2,
      asia: 1.3,
      global: 1.4,
    },
    costModel: {
      baseMonthlyCost: {
        monolith: 90,
        "modular-monolith": 210,
        "scalable-services": 480,
      },
      featureComponentWeight: 20,
      monthlyUsersDivider: 500,
      fastDeliverySurcharge: 0,
      costBreakdown: {
        compute: 0.4,
        database: 0.3,
        storage: 0.1,
        monitoring: 0.1,
        networking: 0.1,
      },
    },
    roadmapRules: {
      includeIdeaStageValidationStep: false,
      includeFileUploadLifecycleStep: true,
      includeRealtimeStressStep: false,
    },
  });

  assert.equal(normalized.regionMultipliers.global, 1.4);
  assert.equal(normalized.costModel.baseMonthlyCost.monolith, 90);
  assert.equal(normalized.costModel.featureComponentWeight, 20);
  assert.equal(normalized.costModel.fastDeliverySurcharge, 0);
  assert.equal(normalized.costModel.costBreakdown.database, 0.3);
  assert.equal(normalized.roadmapRules.includeIdeaStageValidationStep, false);
});

test("normalizeEngineSettings falls back to defaults for invalid numbers and probabilities", () => {
  const normalized = normalizeEngineSettings({
    regionMultipliers: {
      europe: -1,
    },
    costModel: {
      baseMonthlyCost: {
        monolith: "invalid",
      },
      featureComponentWeight: -10,
      monthlyUsersDivider: 0,
      costBreakdown: {
        compute: 1.8,
        database: -0.2,
      },
    },
  });

  assert.equal(normalized.regionMultipliers.europe, DEFAULT_ENGINE_SETTINGS.regionMultipliers.europe);
  assert.equal(
    normalized.costModel.baseMonthlyCost.monolith,
    DEFAULT_ENGINE_SETTINGS.costModel.baseMonthlyCost.monolith,
  );
  assert.equal(
    normalized.costModel.featureComponentWeight,
    DEFAULT_ENGINE_SETTINGS.costModel.featureComponentWeight,
  );
  assert.equal(normalized.costModel.monthlyUsersDivider, DEFAULT_ENGINE_SETTINGS.costModel.monthlyUsersDivider);
  assert.equal(normalized.costModel.costBreakdown.compute, DEFAULT_ENGINE_SETTINGS.costModel.costBreakdown.compute);
  assert.equal(
    normalized.costModel.costBreakdown.database,
    DEFAULT_ENGINE_SETTINGS.costModel.costBreakdown.database,
  );
});

test("normalizeEngineSettings keeps default booleans when non-boolean values are passed", () => {
  const normalized = normalizeEngineSettings({
    roadmapRules: {
      includeIdeaStageValidationStep: "yes",
      includeFileUploadLifecycleStep: null,
      includeRealtimeStressStep: 1,
    },
  });

  assert.deepEqual(normalized.roadmapRules, DEFAULT_ENGINE_SETTINGS.roadmapRules);
});
