# New Learning Community – French Monkeys Academy Starter

Swift starter environment for a mechanic-focused learning platform with:

- **Learner login** and dashboard (scores + achievements)
- **Admin APIs** for adding courses, tests, pages, toolbar links, and announcements
- **JSON-first API design** for easy app/web/mobile integration
- **Snap-on inspired brand colors** (red/black/white) on the landing page

## Stack

- Swift 6
- Custom lightweight Swift HTTP server (no external dependencies)
- In-memory data store (seeded defaults for fast prototyping)

## Run locally

```bash
swift run
```

Server starts on `http://localhost:8080`.

## Seed accounts

- Admin: `admin@frenchmonkeys.io`
- Learner: `student@frenchmonkeys.io`

Get a token:

```bash
curl -s -X POST http://localhost:8080/api/auth/login \
  -H 'content-type: application/json' \
  -d '{"email":"admin@frenchmonkeys.io"}'
```

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
