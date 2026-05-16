const test = require("node:test");
const assert = require("node:assert/strict");

const { evaluateRules } = require("../../engine/ruleEvaluator");

function createEmptyRuleGroups() {
  return {
    baseSelectionRules: [],
    componentEnrichmentRules: [],
    roadmapRules: [],
    conflictRules: [],
    regionRules: [],
  };
}

test("evaluateRules applies operator combinations and tracks applied rule ids", () => {
  const input = {
    monthlyUsers: 1500,
    monthlyBudget: 250,
    tags: ["priority"],
    tier: "pro",
  };

  const ruleGroups = createEmptyRuleGroups();
  ruleGroups.baseSelectionRules = [
    {
      id: "R1",
      when: {
        monthlyUsers: { gte: 1000, lt: 5000 },
      },
      then: {
        architectureStyle: "modular-monolith",
        costProfile: "balanced",
      },
    },
  ];
  ruleGroups.componentEnrichmentRules = [
    {
      id: "R2",
      when: {
        tags: { includes: "priority" },
      },
      then: {
        addComponents: ["queue"],
      },
    },
    {
      id: "R3",
      when: {
        tier: { in: ["pro", "enterprise"] },
      },
      then: {
        addRoadmap: ["Enable performance monitoring early."],
      },
    },
  ];

  const result = evaluateRules(input, ruleGroups);

  assert.equal(result.architectureStyle, "modular-monolith");
  assert.equal(result.costProfile, "balanced");
  assert.deepEqual(result.components, ["queue"]);
  assert.deepEqual(result.roadmap, ["Enable performance monitoring early."]);
  assert.deepEqual(result.appliedRuleIds, ["R1", "R2", "R3"]);
});

test("evaluateRules de-duplicates arrays merged from multiple matched rules", () => {
  const input = { type: "web", growth: "fast" };
  const ruleGroups = createEmptyRuleGroups();

  ruleGroups.baseSelectionRules = [
    {
      id: "B1",
      when: { type: { eq: "web" } },
      then: {
        constraints: ["keep-it-simple"],
        preferences: ["managed-services"],
      },
    },
    {
      id: "B2",
      when: { growth: { eq: "fast" } },
      then: {
        constraints: ["keep-it-simple"],
        preferences: ["managed-services", "scalability"],
      },
    },
  ];

  const result = evaluateRules(input, ruleGroups);

  assert.deepEqual(result.constraints, ["keep-it-simple"]);
  assert.deepEqual(result.preferences, ["managed-services", "scalability"]);
});

test("evaluateRules returns independent default structure when no rules match", () => {
  const result = evaluateRules({ stage: "none" }, createEmptyRuleGroups());

  assert.equal(result.architectureStyle, "monolith");
  assert.equal(result.deploymentModel, "cloud");
  assert.equal(result.costProfile, "minimal");
  assert.deepEqual(result.components, []);
  assert.deepEqual(result.appliedRuleIds, []);
  assert.deepEqual(result.regionAdjustments, {
    costMultiplier: 1,
    restrictedServices: [],
    fallbackServices: [],
  });
});
