import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "node",
    testTimeout: 30_000,
    hookTimeout: 30_000,
    // One file at a time: the integration suite shares a single dev server.
    fileParallelism: false,
  },
});
