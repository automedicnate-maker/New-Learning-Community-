# New Learning Community – French Monkeys Academy Starter

Swift starter environment for a mechanic-focused learning platform with:

- **Learner login** and dashboard (scores + achievements)
- **Admin APIs** for adding courses, tests, pages, toolbar links, and announcements
- **JSON-first API design** for easy app/web/mobile integration
- **Clean Snap-on inspired UI** (red/black/white) with login, dashboard, and admin content forms

## Stack

- Swift 6
- Custom lightweight Swift HTTP server (no external dependencies)
- In-memory data store (seeded defaults for fast prototyping)

## Run locally

```bash
swift run
```

Server starts on `http://localhost:8080`.

## Default credentials

- **Admin username:** `admin`
- **Admin password:** `ChangeMeNow!123`
- Learner username: `learner1`
- Learner password: `LearnerPass!123`

> ⚠️ These are development defaults. Change credentials before production use.

Get an admin token:

```bash
curl -s -X POST http://localhost:8080/api/auth/login \
  -H 'content-type: application/json' \
  -d '{"username":"admin","password":"ChangeMeNow!123"}'
```

## Web UI (user-friendly starter)

The homepage now provides:

- A cleaner dashboard with platform counts and live data tables
- Built-in login form (username/password)
- Admin tools to add courses, announcements, pages, and toolbar links directly from the UI
- Role-aware session display so admins can immediately start managing content

## Key endpoints

### Public

- `GET /` → landing/status page
- `GET /api/bootstrap` → default seeded content summary
- `POST /api/auth/login` → token + role

### Auth required (Bearer token)

- `GET /api/dashboard`
- `GET /api/courses`
- `GET /api/tests`
- `GET /api/announcements`

### Admin only (Bearer admin token)

- `POST /api/admin/courses`
- `POST /api/admin/tests`
- `POST /api/admin/announcements`
- `POST /api/admin/pages`
- `POST /api/admin/toolbar`

## Notes

This is an MVP environment scaffold intended for your next phase (persistent database, quiz attempt tracking, course progression logic, richer auth, and future achievement systems).
