# Task Management APP

Welcome to the task manager APP, this is the first and the **backend** repository, for this project and the frontend lives at [task-management-frontend](https://github.com/paulorivera27/task-management-frontend).

This application was built to make your life easier, and to keep track of any tasks you might forget, just create a simple account, jot something to the task create page and save it, this app will help you update the tasks to keep track of them, delete them when not needed.

Now, going to the more technical side of things, this app can be run everywhere docker is available, do you have a raspberry pi? no worries, a nas? is fine, you can run it everywhere thanks to the dockerized nature of the app itself, this repository was made with ruby on rails in api mode only using cool GraphQL queries and mutations and, as mentioned above, it supports all CRUD operations as well as JWT authentication, when you have too many tasks the offset pagination will make your life easier to navigate and everything just for your registered user.

---

## Tech Stack

| Layer     | Technology                                                                |
| --------- | ------------------------------------------------------------------------- |
| Framework | Ruby on Rails 8.1.4                                                       |
| Language  | Ruby 3.3.5                                                                |
| Database  | PostgreSQL 16                                                             |
| API       | GraphQL (~> 2.5), GraphiQL Interface is available when developing the app |
| Auth      | JWT (jwt gem) + bcrypt + HttpOnly refresh token cookies                   |
| Server    | Puma + Thruster (HTTP/2 proxy) (Rails 8 defaults)                         |
| Testing   | RSpec, FactoryBot, Faker                                                  |
| Linting   | RuboCop                                                                   |
| Security  | Brakeman                                                                  |
| CI/CD     | GitHub Actions (lint, security scan, test)                                |
| Deploy    | Docker, Docker Compose                                                    |

---

## Quick Setup with Docker Compose

This is the fastest way to get the full app running. It readies up the database, backend API, and frontend app in one command.

**Prerequisites:** Docker and Docker Compose installed.

**Both repos must be cloned side by side in the same parent directory:**

```
parent-directory/
├── task-management-api/          # this repository
└── task-management-frontend/     # the frontend repository
```

```bash
# 1. clone both repos
git clone https://github.com/paulorivera27/task-management-api.git
git clone https://github.com/paulorivera27/task-management-frontend.git

# 2. set up environment variables
cd task-management-api
cp .env.example .env
echo "SECRET_KEY_BASE=$(openssl rand -hex 64)" >> .env

# 3. build and start all services
docker compose up --build
```

Once the app is running:

- **Frontend:** http://localhost:3000
- **API endpoint:** http://localhost:4000/graphql

The backend entrypoint automatically runs `db:prepare` on startup, so the database is created and migrated for you.

---

## Local Development Setup (without Docker)

Now, lets talk about setting up the backend for development.

**Prerequisites:**

- Ruby 3.3.5 (recommended via [rbenv](https://github.com/rbenv/rbenv))
- PostgreSQL 16 running locally
- Bundler

```bash
# 1. Clone and enter the repo
git clone https://github.com/paulorivera27/task-management-api.git
cd task-management-api

# 2. Install dependencies
bundle install

# 3. Create and migrate the database
bin/rails db:create db:migrate

# 4. Start the server
bin/rails server -p 4000
```

The API will be available at http://localhost:4000/graphql.

> **Note:** When running locally without Docker, the `DB_HOST`, `DB_USERNAME`, and `DB_PASSWORD` env vars are unset, so Rails falls back to your local PostgreSQL your system user has — no extra configuration needed.

### GraphiQL Interface

In development mode, you can use the GraphQL interface, which is available at http://localhost:4000/graphiql via the browser, this is pretty cool because you get the schema and basically an easy way to create your queries and test them before implementing in the front end.

---

## Environment Variables

Above, in the quick setup section, I mentioned that you have to copy the example env file, i will dig deeper here regarding that, first the file we are copying contains some defaults and example variables, to copy to .env you need to run the following commands:

```bash
cp .env.example .env
echo "SECRET_KEY_BASE=$(openssl rand -hex 64)" >> .env
```

You have to do that mainly because the `SECRET_KEY_BASE` is needed by the app to initialize and to derive the JWT signing key. `.env.example` does not include a value on purpose: the container refuses to start when it is set to a short (under 64 characters) or placeholder value, so nobody can deploy with a publicly known signing secret. Below you will see an explanation of the existing variables:

| Variable            | Default                 | Description                                                                                                                                      |
| ------------------- | ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| `POSTGRES_USER`     | `postgres`              | PostgreSQL superuser (used by the `db` container)                                                                                                |
| `POSTGRES_PASSWORD` | `postgres`              | PostgreSQL superuser password                                                                                                                    |
| `SECRET_KEY_BASE`   | _(none, you generate)_  | Rails secret (the JWT signing key is derived from it). At least 64 characters, e.g. `openssl rand -hex 64`. Never reuse or commit it.             |
| `DB_HOST`           | `db`                    | Database host. no need for local dev.                                                                                                            |
| `DB_USERNAME`       | `postgres`              | Database connection username                                                                                                                     |
| `DB_PASSWORD`       | `postgres`              | Database connection password                                                                                                                     |
| `CORS_ORIGINS`      | `http://localhost:3000` | Allowed CORS origin for the frontend (a single origin)                                                                                           |
| `FORCE_SSL`         | `true`                  | Production only. `true` trusts the TLS-terminating proxy, adds HSTS and `Secure` cookies. `docker-compose.yml` sets `false` for the local HTTP demo. |
| `TRUSTED_PROXIES`   | _(Rails defaults)_      | Production only. Comma-separated CIDRs of every proxy between the client and the app (loopback is always trusted). Rate limits use the client IP, and by default Rails trusts every private-range hop, so clients on a LAN that reach the app directly can spoof `X-Forwarded-For` and dodge the limits. Leave it unset behind Kamal's proxy. If you set it and miss a proxy, all clients share one rate-limit bucket. |
| `REFRESH_COOKIE_SAMESITE` | `strict`          | `strict`, `lax` or `none`. Only use `none` (needs TLS) if the frontend lives on a different site than the API.                                   |

---

## Running Tests

Ok, to run tests you will need to follow the below commands:

```bash
# Run the full test suite
bundle exec rspec

# With detailed output
bundle exec rspec --format documentation

# Run a specific spec file
bundle exec rspec spec/requests/graphql/tasks_spec.rb
```

The test suite includes **112 examples** that cover:

- **Task model** — validations, enum statuses
- **User model** — validations, email normalization, associations, dependent destroy
- **Task queries** — pagination, filtering, single task lookup, user scoping
- **Task mutations** — create, update, delete with auth guards
- **Auth mutations** — sign up, sign in, currentUser query
- **Authorization** — cannot access/modify another user's tasks, unauthenticated access to every operation
- **Refresh tokens** — rotation, grace window, reuse detection, idle and absolute expiry, logout, cookie attributes, rate limits
- **Input handling** — JSON-only transport, invalid variables, pagination bounds, password policy, JWT tampering and expiry

---

## GraphQL Schema

All operations go through a single endpoint: `POST /graphql`

### Queries

| Query                          | Auth Required | Description                                                                        |
| ------------------------------ | :-----------: | ---------------------------------------------------------------------------------- |
| `tasks(status, limit, offset)` |      Yes      | Page of the current user's tasks, newest first. `limit` is 1-100 (default 10), `offset` is 0 or more (default 0). Returns `{ tasks, totalCount }` |
| `task(id)`                     |      Yes      | Single task by ID (scoped to current user)                                         |
| `currentUser`                  |      Yes      | Returns the authenticated user's profile                                           |

### Mutations

| Mutation                                        | Auth Required | Description                                                                                   |
| ----------------------------------------------- | :-----------: | --------------------------------------------------------------------------------------------- |
| `signUp(input: {email, password})`              |      No       | Create account. Returns `{ token, user, errors }` and sets an `HttpOnly` refresh token cookie |
| `signIn(input: {email, password})`              |      No       | Authenticate. Returns `{ token, user, errors }` and sets an `HttpOnly` refresh token cookie   |
| `createTask(input: {title, description?, status?})` |      Yes      | Create a task. Defaults to `PENDING` status                                                   |
| `updateTask(input: {id, title?, description?, status?})` |      Yes      | Update a task (scoped to current user)                                                        |
| `deleteTask(input: {id})`                       |      Yes      | Delete a task (scoped to current user)                                                        |

### REST Auth Endpoints

In addition to the GraphQL mutations, the following REST endpoints handle token refresh and logout:

| Endpoint        | Method | Description                                                                                      |
| --------------- | ------ | ------------------------------------------------------------------------------------------------ |
| `/auth/refresh` | POST   | Reads the `HttpOnly` refresh token cookie, rotates it, and returns a new short-lived access token + user info |
| `/auth/logout`  | DELETE | Revokes the whole refresh token family server-side and clears the cookie                                      |

### Authentication

Include the JWT access token in the `Authorization` header:

```
Authorization: Bearer <token>
```

**Access tokens** are valid for 15 minutes and signed with HS256 using a key derived from `SECRET_KEY_BASE`.

**Refresh tokens** are single-use and rotate on every `/auth/refresh`:

- Only the SHA-256 digest is stored. The raw value lives in an `HttpOnly` cookie scoped to `Path=/auth`, `SameSite=Strict` by default (`REFRESH_COOKIE_SAMESITE` overrides it), and `Secure` whenever the app runs behind TLS.
- Each login starts a token _family_. Every refresh issues a child token in the same family and marks the parent rotated. All changes to a family are serialized with a database advisory lock, so parallel refreshes cannot fork it.
- Replaying a rotated token inside the 10 second window (parallel tabs, or a refresh response that never reached the browser) is tolerated: if none of its children has been used yet, the replay gets a sibling child (3 children per parent at most). Once a child is used, replays of the parent only get an access token, with no new cookie. Using one sibling retires the other siblings.
- Replaying a rotated or retired token after the window is treated as theft: the whole family is revoked and the user must log in again. Whoever refreshes second loses.
- Limits: the thief is only caught when the other side refreshes again, and a retired sibling can still obtain access tokens for the 10 seconds after its retirement. A refresh response lost in transit is only recovered if the client retries inside the window; the bundled frontend does not retry, so in practice siblings serve parallel tabs and React StrictMode. If three overlapping refreshes land out of order, the browser can end up holding a retired token and be logged out about 15 minutes later.
- Idle expiry is 7 days, with an absolute session lifetime of 30 days. Logout revokes the whole family, and a daily job (`PruneRefreshTokensJob`, run by Solid Queue) deletes rows that can no longer be used.

**Transport rules**

- `POST /graphql` only accepts `Content-Type: application/json` (anything else gets `415`), which keeps cross-site form posts out.
- Requests are rate limited per IP (60/min on `/graphql`, 120/min on `/auth/refresh`, `429` with `Retry-After`; see `TRUSTED_PROXIES` for clients on a private network) and only one `signIn`/`signUp` is allowed per GraphQL document.
- Unauthenticated operations fail with the message `Authentication required` and `extensions.code = "UNAUTHENTICATED"`. The frontend relies on the exact message to trigger a refresh.

Example (JSON body, arguments go inside `input`):

```bash
curl -i -X POST http://localhost:4000/graphql \
  -H 'Content-Type: application/json' \
  -d '{"query":"mutation($e:String!,$p:String!){ signIn(input:{email:$e,password:$p}){ token errors } }","variables":{"e":"me@example.com","p":"password123"}}'
```

Passwords must be at least 8 characters (bcrypt ignores anything past 72 bytes, so longer ones are rejected).

### Production and TLS

In production the app expects TLS to terminate at a reverse proxy in front of it (Kamal proxy, nginx, Caddy, a cloud load balancer) that redirects HTTP to HTTPS and forwards `X-Forwarded-Proto`. With `FORCE_SSL` left at its default (`true`) the app trusts that proxy, sends HSTS, and marks the refresh cookie `Secure`. `docker-compose.yml` sets `FORCE_SSL=false` so the demo works over plain `http://localhost`. Remove that line for any real deployment, and never expose the demo stack to a network you do not control.

Rate limits are stored in the Rails cache (Solid Cache in production). A transient cache error is logged (`cache increment failed, rate limits are not enforced`) and that request skips rate limiting, so the API stays up; a missing or misconfigured cache database returns a loud `500` instead. With more than one app instance the limits are shared through that database.

### Deploying with Kamal

`config/deploy.yml` deploys the API and a Postgres 16 accessory to one server, with TLS from Kamal's proxy (Let's Encrypt). Nothing about your infrastructure is stored in git: every value is read from your shell.

```bash
export KAMAL_SERVER=203.0.113.10          # server IP
export KAMAL_HOST=api.example.com         # public host name (DNS must point at the server)
export KAMAL_REGISTRY_USER=your-user      # Docker Hub user, the image is <user>/task-management-api
export KAMAL_REGISTRY_PASSWORD=...        # registry access token
export CORS_ORIGINS=https://app.example.com
export SECRET_KEY_BASE=$(openssl rand -hex 64)
export DB_PASSWORD=$(openssl rand -hex 24)
bin/kamal setup
```

`bin/kamal config` validates the file without touching a server. A real deployment has not been run from this repository, so treat the first `setup` as the test.

Migrations are written to survive a rolling deploy: new `refresh_tokens` columns have database defaults, so containers still running the previous version can keep inserting rows while the new ones start. The refresh-token migration holds a table lock while it backfills, which is instant at this table size.

### Task Status Enum

`PENDING` | `IN_PROGRESS` | `COMPLETED`

---

## Project Structure

```
app/
├── jobs/
│   └── prune_refresh_tokens_job.rb  # daily cleanup of dead refresh tokens
├── controllers/
│   ├── graphql_controller.rb     # GraphQL endpoint, JSON-only, JWT extraction
│   ├── auth_controller.rb        # REST endpoints for token refresh and logout
│   └── concerns/refresh_cookie.rb  # cookie flags (HttpOnly, Secure, SameSite, Path=/auth)
├── graphql/
│   ├── auth_guard.rb              # shared "Authentication required" guard
│   ├── analyzers/                 # one signIn/signUp per document
│   ├── mutations/
│   │   ├── create_task.rb
│   │   ├── update_task.rb
│   │   ├── delete_task.rb
│   │   ├── sign_up.rb
│   │   └── sign_in.rb
│   └── types/
│       ├── query_type.rb          # tasks, task, currentUser queries
│       ├── mutation_type.rb
│       ├── task_type.rb
│       ├── tasks_result_type.rb   # { tasks, totalCount } wrapper
│       ├── task_status_enum.rb
│       └── user_type.rb
├── models/
│   ├── refresh_token.rb           # single-use refresh tokens (SHA-256 hashed, rotation, families)
│   ├── task.rb                    # belongs_to :user, enum status
│   └── user.rb                    # has_secure_password, has_many :tasks
└── services/
    └── auth_token.rb              # JWT encode/decode (HS256, 15min expiry, derived key)

spec/
├── factories/
│   ├── tasks.rb
│   └── users.rb
├── jobs/
│   └── prune_refresh_tokens_job_spec.rb
├── models/
│   ├── refresh_token_concurrency_spec.rb  # real threads: races between refresh, replay and logout
│   ├── refresh_token_spec.rb
│   ├── task_spec.rb
│   └── user_spec.rb
├── services/
│   └── auth_token_spec.rb
└── requests/
    ├── auth_refresh_spec.rb       # /auth/refresh, /auth/logout, cookie attributes
    └── graphql/
        ├── tasks_spec.rb
        ├── auth_spec.rb
        └── security_spec.rb       # transport, auth guard, pagination bounds, limits
```

---

## CI/CD

GitHub Actions runs three jobs on every pull request and on every push to `master`:

| Job         | What it does                                                       |
| ----------- | ------------------------------------------------------------------ |
| `scan_ruby` | Brakeman (security analysis) + Bundler Audit (gem vulnerabilities) |
| `lint`      | RuboCop with caching                                               |
| `test`      | RSpec against PostgreSQL 16 service container                      |

---

## License

Released under the [MIT License](LICENSE).
