const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');

const PROJECT_ROOT = 'C:/Users/Manmade/Desktop/Alina';

const {
  normalizeRole,
  assertValidRole,
  parseUserTarget,
} = require(path.join(PROJECT_ROOT, 'backend/src/utils/admin.js'));

const {
  normalizeComplaintStatus,
} = require(path.join(PROJECT_ROOT, 'backend/src/utils/complaint.js'));

const {
  normalizeTicketPriority,
  normalizeTicketStatus,
} = require(path.join(PROJECT_ROOT, 'backend/src/utils/ticket.js'));

const {
  normalizeStatusCode,
  canTransitionShipmentStatus,
  isFinalShipmentStatus,
  generateTrackingNumber,
} = require(path.join(PROJECT_ROOT, 'backend/src/utils/shipment.js'));

const {
  roleToModules,
} = require(path.join(PROJECT_ROOT, 'backend/src/services/employee-access.js'));

const {
  upsertRecipientClient,
} = require(path.join(PROJECT_ROOT, 'backend/src/services/client-access.js'));

const {
  getAdminReportData,
} = require(path.join(PROJECT_ROOT, 'backend/src/services/admin-report.js'));

test('normalizeRole trims and lowercases role', () => {
  assert.equal(normalizeRole('  AdMin  '), 'admin');
});

test('assertValidRole returns true only for supported roles', () => {
  assert.equal(assertValidRole('support'), true);
  assert.equal(assertValidRole('manager'), false);
});

test('parseUserTarget parses valid params', () => {
  const req = { params: { kind: 'Client', id: '42' } };
  assert.deepEqual(parseUserTarget(req), { kind: 'client', id: 42 });
});

test('parseUserTarget returns null for invalid params', () => {
  assert.equal(parseUserTarget({ params: { kind: 'admin', id: '42' } }), null);
  assert.equal(parseUserTarget({ params: { kind: 'employee', id: '0' } }), null);
  assert.equal(parseUserTarget({ params: { kind: 'client', id: 'abc' } }), null);
});

test('normalizeComplaintStatus validates known statuses', () => {
  assert.equal(normalizeComplaintStatus(' In_Progress '), 'in_progress');
  assert.equal(normalizeComplaintStatus('deferred'), '');
});

test('normalizeTicketPriority and normalizeTicketStatus normalize input', () => {
  assert.equal(normalizeTicketPriority(' UrGeNt '), 'urgent');
  assert.equal(normalizeTicketStatus(' closed '), 'closed');
  assert.equal(normalizeTicketStatus('queued'), '');
});

test('normalizeStatusCode trims and lowercases shipment status', () => {
  assert.equal(normalizeStatusCode(' In_Transit '), 'in_transit');
});

test('canTransitionShipmentStatus validates allowed and forbidden transitions', () => {
  assert.equal(canTransitionShipmentStatus('created', 'accepted'), true);
  assert.equal(canTransitionShipmentStatus('created', 'created'), false);
  assert.equal(canTransitionShipmentStatus('delivered', 'cancelled'), false);
});

test('isFinalShipmentStatus detects final states', () => {
  assert.equal(isFinalShipmentStatus('returned'), true);
  assert.equal(isFinalShipmentStatus('accepted'), false);
});

test('generateTrackingNumber returns deterministic value with stubbed Math.random', () => {
  const originalRandom = Math.random;
  Math.random = () => 0;

  try {
    const tracking = generateTrackingNumber();
    assert.equal(tracking, 'PSAAAAAAAAAA');
    assert.equal(/^PS[A-Z0-9]{10}$/.test(tracking), true);
  } finally {
    Math.random = originalRandom;
  }
});

test('roleToModules returns role-based module list', () => {
  assert.deepEqual(roleToModules('admin'), ['Users', 'Offices', 'Shipment Queue', 'Reports']);
  assert.deepEqual(roleToModules('unknown'), []);
});

test('upsertRecipientClient rejects empty full name', async () => {
  const mockClient = { query: async () => ({ rowCount: 0, rows: [] }) };

  await assert.rejects(
    () => upsertRecipientClient(mockClient, { full_name: '   ', email: 'test@example.com' }),
    (error) => error.message === 'Recipient full name is required'
  );
});

test('upsertRecipientClient rejects missing recipient in DB (stubbed dependency)', async () => {
  const mockClient = {
    query: async () => ({ rowCount: 0, rows: [] }),
  };

  await assert.rejects(
    () => upsertRecipientClient(mockClient, { full_name: 'Jane Doe', email: 'jane@example.com' }),
    (error) =>
      error.message === 'Recipient client not found. Ask recipient to register first.' && error.statusCode === 404
  );
});

test('upsertRecipientClient returns existing recipient row (stubbed dependency)', async () => {
  const row = {
    client_id: 7,
    full_name: 'Jane Doe',
    email: 'jane@example.com',
    address: 'Minsk',
    phone: '+375291112233',
  };

  const mockClient = {
    query: async () => ({ rowCount: 1, rows: [row] }),
  };

  const result = await upsertRecipientClient(mockClient, { full_name: 'Jane Doe', email: 'JANE@example.com' });
  assert.deepEqual(result, row);
});

test('getAdminReportData builds report from stubbed pool.query responses', async () => {
  const responses = [
    {
      rows: [
        {
          total_clients: 2,
          total_employees: 3,
          total_operators: 1,
          total_support: 1,
          total_admins: 1,
          total_post_offices: 1,
          total_shipments: 4,
          total_tracking_events: 8,
          total_reviews: 5,
          avg_review_rating: '4.50',
        },
      ],
    },
    {
      rows: [{ code: 'created', name: 'Created', items_count: 4 }],
    },
    {
      rows: [
        {
          user_id: 10,
          full_name: 'Operator One',
          email: 'op1@example.com',
          created_at: '2026-01-01T00:00:00.000Z',
          post_index: '220000',
          office_address: 'Office 1',
          tracking_updates_count: 12,
          last_tracking_update_at: '2026-01-02T00:00:00.000Z',
          items_currently_at_office: 5,
        },
      ],
    },
    {
      rows: [
        {
          user_id: 11,
          full_name: 'Support One',
          email: 'sup1@example.com',
          created_at: '2026-01-01T00:00:00.000Z',
          post_index: '220001',
          office_address: 'Office 2',
        },
      ],
    },
    {
      rows: [
        {
          user_id: 12,
          full_name: 'Admin One',
          email: 'admin1@example.com',
          created_at: '2026-01-01T00:00:00.000Z',
        },
      ],
    },
    {
      rows: [
        {
          post_office_id: 1,
          post_index: '220050',
          address: 'Main office',
          phone: '+375172222222',
          created_at: '2026-01-01T00:00:00.000Z',
          employees_count: 3,
          operators_count: 1,
          support_count: 1,
          shipments_sent_count: 9,
          shipments_currently_here_count: 2,
          tracking_events_count: 18,
          reviews_count: 6,
          avg_rating: '4.40',
        },
      ],
    },
  ];

  const executedQueries = [];
  const pool = {
    query: async (queryText) => {
      executedQueries.push(queryText);
      return responses[executedQueries.length - 1];
    },
  };

  const report = await getAdminReportData(pool);

  assert.equal(executedQueries.length, 6);
  assert.equal(report.summary.total_clients, 2);
  assert.equal(report.shipment_statuses.length, 1);
  assert.equal(report.operators.length, 1);
  assert.equal(report.support_specialists.length, 1);
  assert.equal(report.admins.length, 1);
  assert.equal(report.post_offices.length, 1);
  assert.equal(Number.isNaN(Date.parse(report.generated_at)), false);
});
