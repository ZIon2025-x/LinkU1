import { afterEach } from 'vitest';
import { cleanup } from '@testing-library/react';

// Ensure @testing-library/react cleanup runs after each test
// (needed because vitest globals:false means afterEach isn't auto-detected)
afterEach(() => {
  cleanup();
});
