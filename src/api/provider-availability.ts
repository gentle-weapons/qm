import type { ModelCredentialStore } from "../model/model-credential-store.ts";
import {
  ALL_PROVIDERS_AVAILABLE,
  modelProviderAvailabilityFor,
  type ModelProviderAvailability,
} from "../model/pi-models.ts";

export interface ProviderAvailabilityDeps {
  providerKeys?: ModelProviderAvailability;
  modelCredentials?: ModelCredentialStore;
}

export interface ProviderAvailability {
  managed: ModelProviderAvailability;
  forHarness(harnessId: string): ModelProviderAvailability;
}

export async function providerAvailability(deps: ProviderAvailabilityDeps): Promise<ProviderAvailability> {
  const configured = deps.providerKeys ?? ALL_PROVIDERS_AVAILABLE;
  const managed = deps.modelCredentials ? await deps.modelCredentials.availability() : configured;
  return { managed, forHarness: (harnessId) => modelProviderAvailabilityFor(harnessId, configured, managed) };
}
