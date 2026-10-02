-- =============================================================================
-- PHASE 0: Prerequisites
-- Warehouse, Secrets, API Integration, Git Repository
-- =============================================================================
-- IMPORTANT: Replace placeholder values marked with <...> before running.
-- NEVER commit actual passwords or tokens to version control.
-- =============================================================================

USE ROLE ACCOUNTADMIN;

-- Warehouse (skip if COMPUTE_WH already exists)
CREATE WAREHOUSE IF NOT EXISTS COMPUTE_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  COMMENT = 'Default compute warehouse for Supply Chain project';

-- =============================================================================
-- GitHub Secret (for private repo access)
-- =============================================================================
-- Replace <YOUR_GITHUB_USERNAME> and <YOUR_GITHUB_PAT> with your values.
-- Generate a PAT at: https://github.com/settings/tokens
-- Required scopes: repo (full control of private repositories)

USE SCHEMA SUPPLY_CHAIN_HUB.SC_GOV;

CREATE OR REPLACE SECRET SECRET_SNOWCHAIN
  TYPE = PASSWORD
  USERNAME = '<YOUR_GITHUB_USERNAME>'
  PASSWORD = '<YOUR_GITHUB_PERSONAL_ACCESS_TOKEN>'
  COMMENT = 'GitHub credentials for snowflake-supply-chain repo';

-- =============================================================================
-- API Integration (Git HTTPS)
-- =============================================================================
-- Replace the API_ALLOWED_PREFIXES with your GitHub account URL.

CREATE OR REPLACE API INTEGRATION SNOWFLAKE_SUPPLY_CHAIN_PROJECT
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/<YOUR_GITHUB_USERNAME>/')
  ALLOWED_AUTHENTICATION_SECRETS = (SUPPLY_CHAIN_HUB.SC_GOV.SECRET_SNOWCHAIN)
  ENABLED = TRUE;

-- =============================================================================
-- Git Repository Object (read-only pull from GitHub into Snowflake)
-- =============================================================================
-- Replace <YOUR_GITHUB_USERNAME> and <YOUR_REPO_NAME> with your values.

CREATE OR REPLACE GIT REPOSITORY SUPPLY_CHAIN_HUB.SC_GOV.SNOWFLAKE_SUPPLY_CHAIN_PUBLIC_REPO
  API_INTEGRATION = SNOWFLAKE_SUPPLY_CHAIN_PROJECT
  ORIGIN = 'https://github.com/<YOUR_GITHUB_USERNAME>/<YOUR_REPO_NAME>.git';

-- Fetch latest from remote
ALTER GIT REPOSITORY SUPPLY_CHAIN_HUB.SC_GOV.SNOWFLAKE_SUPPLY_CHAIN_PUBLIC_REPO FETCH;

-- Verify
SHOW GIT BRANCHES IN SUPPLY_CHAIN_HUB.SC_GOV.SNOWFLAKE_SUPPLY_CHAIN_PUBLIC_REPO;
