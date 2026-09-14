import { z } from 'zod';

export const minimumAgePolicyVersion = 1 as const;

export const minimumAgeAssertionShape = {
  minimumAgeConfirmed: z.literal(true),
  agePolicyVersion: z.literal(minimumAgePolicyVersion),
};
