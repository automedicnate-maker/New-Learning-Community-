# WRENCH Learning Platform

WRENCH is a mechanic training platform with admin and learner workflows.

## What is implemented

- Username/password auth (`login` + `signup`)
- Default owner admin account
- Admin invite code generation for creating additional admin accounts
- Role-based admin center for creating:
  - tools
  - courses (with sections + chapters)
  - tests
  - announcements
- Learner course access rules based on:
  - declared level (beginner/intermediate/advanced)
  - prerequisite passed tests
- Test submission endpoint that records pass/fail attempts

## Default owner admin

- Username: `wrenchadmin`
- Password: `ChangeMeNow!123`

> Change this immediately in a real deployment.

## Architecture

- See the comprehensive implementation blueprint: `docs/gidipea-architecture-implementation-plan.md`.
- The API now supports community-aware data isolation using `x-community-slug` header on authenticated requests.

## Run

```bash
swift run
```

App runs at `http://localhost:8080`.

## Core API

### Public
- `GET /api/bootstrap`
- `POST /api/auth/login`
- `POST /api/auth/signup`

### Authenticated user
- `GET /api/communities`
- `GET /api/dashboard`
- `GET /api/courses`
- `GET /api/tests`
- `GET /api/tools`
- `GET /api/announcements`
- `POST /api/tests/submit`

### Admin only
- `POST /api/admin/communities`
- `POST /api/admin/community-members`
- `GET /api/admin/overview`
- `POST /api/admin/invite-codes`
- `POST /api/admin/tools`
- `POST /api/admin/courses`
- `POST /api/admin/tests`
- `POST /api/admin/announcements`

## Notes

Data is currently in-memory for rapid iteration. Persisting to a real database is the next production step.


## Community scoping

Set `x-community-slug` on authenticated requests (dashboard/courses/tests/tools/announcements/test submission) to select the active community.

If omitted, the first community membership is used.
