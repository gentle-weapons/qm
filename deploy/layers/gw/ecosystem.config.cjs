const appRoot = process.env.GW_QM_APP_ROOT || process.cwd();
const envFile = `${appRoot}/.env`;

module.exports = {
  apps: [
    {
      name: "qm-core",
      cwd: appRoot,
      script: "node",
      args: `--env-file-if-exists=${envFile} src/index.ts`,
      env: {
        NODE_ENV: "production",
        PORT: "3000",
      },
      max_restarts: 10,
      min_uptime: "10s",
    },
    {
      name: "qm-worker",
      cwd: appRoot,
      script: "node",
      args: `--env-file-if-exists=${envFile} src/runs/worker-main.ts`,
      env: {
        NODE_ENV: "production",
      },
      max_restarts: 10,
      min_uptime: "10s",
    },
    {
      name: "qm-web-ui",
      cwd: `${appRoot}/plugins/web-ui`,
      script: "node",
      args: `--env-file-if-exists=${envFile} server/index.ts`,
      env: {
        NODE_ENV: "production",
        PORT: "3001",
        CORE_API_URL: "http://127.0.0.1:3000",
      },
      max_restarts: 10,
      min_uptime: "10s",
    },
    {
      name: "qm-admin",
      cwd: `${appRoot}/plugins/admin`,
      script: "node",
      args: `--env-file-if-exists=${envFile} src/index.ts`,
      env: {
        NODE_ENV: "production",
        PORT: "3002",
        CORE_API_URL: "http://127.0.0.1:3000",
        ADMIN_BASE_PATH: "/admin",
      },
      max_restarts: 10,
      min_uptime: "10s",
    },
    {
      name: "qm-portal",
      cwd: `${appRoot}/plugins/portal`,
      script: "node",
      args: `--env-file-if-exists=${envFile} src/index.ts`,
      env: {
        NODE_ENV: "production",
        PORT: "8080",
        CORE_API_URL: "http://127.0.0.1:3000",
        WEB_UI_UPSTREAM: "http://127.0.0.1:3001",
        ADMIN_UPSTREAM: "http://127.0.0.1:3002",
      },
      max_restarts: 10,
      min_uptime: "10s",
    },
  ],
};
