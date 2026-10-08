import { decryptSecret, deriveConnectorKey, encryptSecret } from "../connectors/connector-client-store.ts";
import type { DurableMap } from "../persistence/durable-map.ts";
import { errMessage } from "../util/errors.ts";
import { MODEL_PROVIDERS, type ModelProvider, type ModelProviderAvailability } from "./pi-models.ts";

export interface StoredModelCredential {
  provider: ModelProvider;
  secretEnc?: string;
  disabled?: boolean;
  updatedAt: number;
  updatedBy: string;
}

interface ModelCredentialStatus {
  provider: ModelProvider;
  configured: boolean;
  source: "admin" | "environment" | "absent";
  updatedAt?: number;
  updatedBy?: string;
}

export interface ModelCredentialStore {
  resolve(provider: ModelProvider): Promise<string | null>;
  set(provider: ModelProvider, apiKey: string, updatedBy: string): Promise<void>;
  delete(provider: ModelProvider, updatedBy: string): Promise<void>;
  statuses(): Promise<ModelCredentialStatus[]>;
  availability(): Promise<ModelProviderAvailability>;
  keys(): Promise<Partial<Record<ModelProvider, string>>>;
}

export function createModelCredentialStore(input: {
  backing: DurableMap<StoredModelCredential>;
  keyMaterial: string | Buffer;
  fallback?: Partial<Record<ModelProvider, string>>;
}): ModelCredentialStore {
  const key = deriveConnectorKey(input.keyMaterial, "model-credentials");

  async function record(provider: ModelProvider): Promise<StoredModelCredential | null> {
    return input.backing.get(provider);
  }

  const reportedUnreadable = new Set<string>();

  function adminSecret(saved: StoredModelCredential | null): string | null {
    if (!saved?.secretEnc || saved.disabled) return null;
    try {
      return decryptSecret(saved.secretEnc, key);
    } catch (error) {
      const record = `${saved.provider}:${saved.updatedAt}`;
      if (!reportedUnreadable.has(record)) {
        reportedUnreadable.add(record);
        console.error(`[model] provider ${saved.provider}: key unreadable: ${errMessage(error)}`);
      }
      return null;
    }
  }

  return {
    async resolve(provider) {
      const saved = await record(provider);
      if (saved?.disabled) return null;
      return adminSecret(saved) || input.fallback?.[provider]?.trim() || null;
    },

    async set(provider, apiKey, updatedBy) {
      const secret = apiKey.trim();
      if (!secret) throw new Error("API key is required");
      const actor = updatedBy.trim();
      if (!actor) throw new Error("updatedBy is required");
      await input.backing.put(provider, {
        provider,
        secretEnc: encryptSecret(secret, key),
        disabled: false,
        updatedAt: Date.now(),
        updatedBy: actor,
      });
    },

    async delete(provider, updatedBy) {
      await input.backing.put(provider, {
        provider,
        disabled: true,
        updatedAt: Date.now(),
        updatedBy,
      });
    },

    async statuses() {
      return Promise.all(
        MODEL_PROVIDERS.map(async (provider): Promise<ModelCredentialStatus> => {
          const saved = await record(provider);
          const adminStatus = (configured: boolean): ModelCredentialStatus => ({
            provider,
            configured,
            source: "admin",
            updatedAt: saved!.updatedAt,
            updatedBy: saved!.updatedBy,
          });
          if (saved && adminSecret(saved)) return adminStatus(true);
          if (saved?.disabled) return adminStatus(false);
          if (input.fallback?.[provider]?.trim()) return { provider, configured: true, source: "environment" };
          return saved ? adminStatus(false) : { provider, configured: false, source: "absent" };
        }),
      );
    },

    async availability() {
      const statuses = await this.statuses();
      return Object.fromEntries(
        statuses.map((status) => [status.provider, status.configured]),
      ) as ModelProviderAvailability;
    },

    async keys() {
      const resolved = await Promise.all(
        MODEL_PROVIDERS.map(async (provider) => [provider, await this.resolve(provider)] as const),
      );
      return Object.fromEntries(resolved.filter(([, key]) => key)) as Partial<Record<ModelProvider, string>>;
    },
  };
}
