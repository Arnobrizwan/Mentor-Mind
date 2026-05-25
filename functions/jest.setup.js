/** Global mocks for firebase-functions params (Stripe callables). */
jest.mock('firebase-functions/params', () => ({
  defineString: (name, opts) => ({
    value: () => opts?.default ?? `mock-${name}`,
  }),
  defineSecret: () => ({
    value: () => 'sk_test_mock',
  }),
}));
