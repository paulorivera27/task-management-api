# Task Management APP

Welcome to the task manager APP, this is the first and the **backend** repository, for this project and the frontend lives at [task-management-frontend](https://github.com/paulorivera27/task-management-frontend).

This application was built to make your life easier, and to keep track of any tasks you might forget, just create a simple account, jot something to the task create page and save it, this app will help you update the tasks to keep track of them, delete them when not needed.

Now, going to the more technical side of things, this app can be run everywhere docker is available, do you have a raspberry pi? no worries, a nas? is fine, you can run it everywhere thanks to the dockerized nature of the app itself, this repository was made with ruby on rails in api mode only using cool GraphQL queries and mutaiuons and as i mentioned above, it supports all CRUD operations as well as JWT authentication, when you have too many tasks the offset pagination will make your life easier to navigate and everything just for your registered user.

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Ruby on Rails 8.1.2 |
| Language | Ruby 3.3.5 |
| Database | PostgreSQL 16 |
| API | GraphQL (~> 2.5), GraphiQL Interface is available when developing the app |
| Auth | JWT (jwt gem) + bcrypt |
| Server | Puma + Thruster (HTTP/2 proxy) (Rails 8 defaults) |
| Testing | RSpec, FactoryBot, Faker |
| Linting | RuboCop |
| Security | Brakeman |
| CI/CD | GitHub Actions (lint, security scan, test) |
| Deploy | Docker, Docker Compose |

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

# 5. Start the server
bin/rails server -p 4000
```

The API will be available at http://localhost:4000/graphql.

> **Note:** When running locally without Docker, the `DB_HOST`, `DB_USERNAME`, and `DB_PASSWORD` env vars are unset, so Rails falls back to your local PostgreSQL your system user has — no extra configuration needed.

### GraphiQL Interface

In development mode, you can use the GraphQL interface and is available at http://localhost:4000/graphiql via the browser, this is pretty cool because you get the schema and basically an easy way to create your queries and test them before implementing in the front end.

---

## Environment Variables

So above in the quick setup section i mentioned that you have to copy the example env file, i will dig deeper here regarding that, first the file we are copying contains some defaults and example variables, to copy to .env you need to run the following command:

```bash
cp .env.example .env
```

You have to do that mainly because the SECRET_KEY_BASE which is needed by JWT and the App to initialize, so please run the command above before running any docker compose, below you will see an explanation of the existing variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `POSTGRES_USER` | `postgres` | PostgreSQL superuser (used by the `db` container) |
| `POSTGRES_PASSWORD` | `postgres` | PostgreSQL superuser password |
| `SECRET_KEY_BASE` | `insecure_key_for_dev` | Rails secret key (used for JWT signing). **Of course we need to replace this in production, but for demonstration purposes we used that value.** |
| `DB_HOST` | `db` | Database host. no need for local dev. |
| `DB_USERNAME` | `postgres` | Database connection username |
| `DB_PASSWORD` | `postgres` | Database connection password |
| `CORS_ORIGINS` | `http://localhost:3000` | Allowed CORS origin for the frontend |

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

The test suite includes **36 examples** that covers:

- **Task model** — validations, enum statuses
- **User model** — validations, email normalization, associations, dependent destroy
- **Task queries** — pagination, filtering, single task lookup, user scoping
- **Task mutations** — create, update, delete with auth guards
- **Auth mutations** — sign up, sign in, currentUser query
- **Authorization** — cannot access/modify another user's tasks

---

## GraphQL Schema

All operations go through a single endpoint: `POST /graphql`

### Queries

| Query | Auth Required | Description |
|-------|:---:|-------------|
| `tasks(status, limit, offset)` | Yes | Paginated list of the current user's tasks. and it returns `{ tasks, totalCount }` |
| `task(id)` | Yes | Single task by ID (scoped to current user) |
| `currentUser` | Yes | Returns the authenticated user's profile |

### Mutations

| Mutation | Auth Required | Description |
|----------|:---:|-------------|
| `signUp(email, password)` | No | Create account. Returns `{ token, user, errors }` |
| `signIn(email, password)` | No | Authenticate. Returns `{ token, user, errors }` |
| `createTask(title, description?, status?)` | Yes | Create a task. Defaults to `PENDING` status |
| `updateTask(id, title?, description?, status?)` | Yes | Update a task (scoped to current user) |
| `deleteTask(id)` | Yes | Delete a task (scoped to current user) |

### Authentication

Include the JWT token in the `Authorization` header:

```
Authorization: Bearer <token>
```

Tokens are valid for 24 hours and signed with HS256 using `SECRET_KEY_BASE`.

### Task Status Enum

`PENDING` | `IN_PROGRESS` | `COMPLETED`

---

## Project Structure

```
app/
├── controllers/
│   └── graphql_controller.rb     # GraphQL endpoint ans JWT extraction
├── graphql/
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
│   ├── task.rb                    # belongs_to :user, enum status
│   └── user.rb                    # has_secure_password, has_many :tasks
└── services/
    └── auth_token.rb              # JWT encode/decode (HS256, 24h expiry)

spec/
├── factories/
│   ├── tasks.rb
│   └── users.rb
├── models/
│   ├── task_spec.rb
│   └── user_spec.rb
└── requests/graphql/
    ├── tasks_spec.rb
    └── auth_spec.rb
```

---

## CI/CD

GitHub Actions runs three jobs on every push and pull request to `master`:

| Job | What it does |
|-----|-------------|
| `scan_ruby` | Brakeman (security analysis) + Bundler Audit (gem vulnerabilities) |
| `lint` | RuboCop with caching |
| `test` | RSpec against PostgreSQL 16 service container |

---
