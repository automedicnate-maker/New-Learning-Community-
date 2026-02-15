# Gidipea Learning Ecosystem: Comprehensive Architecture & Implementation Plan

## 1. Vision and Strategic Goals

### Purpose
Build a **knowledge civilization engine** (not just a course site) that develops diagnostic reasoning and professional capability through:
- hypothesis-driven thinking,
- controlled testing,
- failure analysis,
- and transferable mental models.

The platform should begin with automotive and HVAC while remaining extensible to diesel, fabrication, robotics, and adjacent disciplines.

### Strategic Objectives
- **Unified identity + multi-community platform**: one account/profile across all communities, with campus-level branding and content isolation.
- **Durable architecture**: shared platform services (identity, search, AI pipeline, analytics, gamification) with community-specific domains (courses, fixes, forums, concept graph).
- **Structured diagnostics pedagogy**: observation -> hypothesis -> test -> interpretation -> failure mode.
- **AI-assisted content pipeline**: ingestion, draft generation, similarity checks, human approval, source traceability.
- **Mastery-based gamification**: reward high-quality diagnostic reasoning and competency progression, not only completion.

---

## 2. Target Architecture

### 2.1 Near-term (current repository alignment)
Current app is a single Swift service with in-memory data. Keep monolith deployment, but enforce module boundaries to support later extraction.

**Bounded modules in the monolith**
- Identity & access
- Community tenancy
- Curriculum & assessments
- Fix library
- Concept graph adapters
- Search index adapters
- AI pipeline orchestration
- Gamification engine adapter
- Audit/analytics

### 2.2 Mid/long-term evolution
- Keep core APIs stable.
- Extract high-load domains (search, embeddings, AI generation, gamification) into independent services.
- Move from in-memory store to PostgreSQL first, then selectively split by domain.

### 2.3 Suggested stack
- **Frontend**: Next.js (or React + Vite) + Tailwind; theme per community.
- **Backend API**: Swift service can remain gateway/edge service; integrate additional Node/FastAPI/Go services as needed.
- **Database**: PostgreSQL (Supabase acceptable) with JSONB where needed.
- **Auth**: Supabase Auth or Keycloak (OIDC/OAuth2 + MFA).
- **Storage**: object storage for docs/media.

---

## 3. Multi-Community Tenancy Model

### Core entities
- `Community(id, slug, name, description, branding_config, status)`
- `CommunityMember(id, community_id, user_id, role, joined_at)`
- `RoleScope`: platform roles + community-scoped roles.

### Isolation requirements
Every query and write in shared services must scope by `community_id`.

Apply this to:
- search index docs,
- vector embeddings,
- gamification events,
- analytics aggregates,
- moderation and audit logs.

---

## 4. Domain Model

### 4.1 Learning structure
- `Course -> Module -> Lesson -> Quiz`
- `Lesson.status`: draft, reviewed, field_tested, published
- `LessonProgress(user_id, lesson_id, completion, score, timestamps)`

### 4.2 Fix library
- `FixEntry(community_id, symptoms/codes, diagnostic_procedure, causes, safety_notes, related_lessons)`

### 4.3 Discussion layer
- Forum threads linked to `lesson_id`, `concept_id`, `fix_entry_id`, or domain code (e.g., DTC).
- Moderation log with actor, action, timestamp, rationale.

### 4.4 Concept graph
- `Concept(id, community_id, label, description)`
- `ConceptRelation(source, relation_type, target)`
- Mappings from concept to lessons/fixes/quizzes/threads.

### 4.5 Gamification
- `PointsLedger(user_id, community_id, event_type, points, metadata, created_at)`
- `BadgeAward(user_id, community_id, badge_id, awarded_at)`
- Skill-tree milestones mapped to concrete competency evidence.

---

## 5. AI-Assisted Content Pipeline

### 5.1 Ingestion
- Upload PDFs/manuals/internal docs.
- Parse + chunk + metadata extraction.
- Persist source data with licensing and provenance:
  - `Document`, `DocumentChunk`, `DocumentLicense`.

### 5.2 Retrieval layer
- Embeddings in Milvus/Qdrant/Weaviate or OpenSearch vector engine.
- Graph extraction pipeline into Neo4j/ArangoDB for concept relationships.

### 5.3 Draft generation
- RAG orchestration via LangChain and/or LlamaIndex.
- Optional authoring UX via Dify/RAGFlow.
- Generate:
  - `DraftCourse`, `DraftModule`, `DraftLesson`, `DraftQuiz`
- Store source chunk references + model metadata per generation.

### 5.4 Quality and originality controls
- Similarity thresholds against source corpus.
- Workflow states: `generated -> flagged(optional) -> instructor_review -> approved/rejected`.
- Mandatory human approval before publish.

---

## 6. Search, Retrieval, and Reasoning UX

### Search architecture
- OpenSearch as primary lexical + analytics engine.
- Vector search either in OpenSearch or dedicated vector DB.

### Retrieval behaviors
- Query filters: `community_id`, entity type, level, tags, safety-critical flag.
- Hybrid retrieval (BM25 + vector).
- Citation-ready responses for AI assistants.

### Concept-first exploration
Support queries like:
- “Show CAN bus diagnostics involving voltage drop.”
- “Find failure cases where initial hypothesis was wrong.”

---

## 7. Collaboration Surfaces

### Forum options
Preferred: **Discourse** or **NodeBB** (integration, moderation, UX).

### Chat agents
- Botpress or Rasa for conversational workflows.
- RAG-grounded on the community corpus.
- Response policies should prioritize safety notes and traceable sources.

### Knowledge base
BookStack (simple), MediaWiki (power/extensibility), or DokuWiki (lightweight).

---

## 8. Gamification and Mastery Model

### Principles
- Reward diagnostic process quality, not just task completion.
- Penalize unsafe reasoning patterns where appropriate.
- Encourage reflective post-mortems after failed diagnosis paths.

### Implementation
- Integrate GAME engine (FastAPI + SQLModel) as external scoring service or internal module.
- Strategy-based scoring (deterministic + adaptive).
- Community-specific skill trees (e.g., electrical diagnostics, network analysis, refrigerant systems).

---

## 9. Security, Compliance, and Trust

- RBAC with platform and community scopes.
- TLS in transit + encryption at rest.
- Audit log for admin/mod/content actions.
- License tracking for all source materials.
- Data export/deletion support.
- AI safety logging with minimal personal data retention.

---

## 10. Observability and Analytics

- Metrics: Prometheus + Grafana.
- Logs: OpenSearch or Loki.
- Product analytics: Postgres/ClickHouse + Metabase.
- Key dashboards:
  - diagnostic simulation funnel,
  - concept mastery progression,
  - content quality and review latency,
  - search relevance and zero-result rates.

---

## 11. Phased Delivery Roadmap

### Phase 0 — Foundation
- Replace in-memory persistence with PostgreSQL.
- Add `Community` and `CommunityMember` models.
- Establish RBAC scope rules and audit log baseline.
- Deploy forum + knowledge base with SSO.

### Phase 1 — Automotive MVP
- Course authoring + ingestion pipeline.
- Initial fix library (DTC oriented).
- Search integration and learner progress.
- Human-reviewed AI draft workflow.

### Phase 2 — Diagnostic Intelligence
- Decision-tree diagnostic simulations with cost/time constraints.
- Skill trees + adaptive scoring.
- Concept mastery dashboards + RAG assistant.

### Phase 3 — Multi-Community Expansion
- Launch HVAC campus using same platform services.
- Ingest HVAC corpus and build specialized fixes.
- Maintain strict community isolation while enabling shared account identity.

### Phase 4 — Scale and Monetization
- Horizontal scaling (Kubernetes, replicated stateful services).
- Certification tracks and verifiable credentials.
- Subscription/payments and ecosystem marketplace integrations.

---

## 12. Immediate Engineering Actions for This Repository

1. Introduce database-backed storage (PostgreSQL) and migration tooling.
2. Add tenancy-aware data model (`community_id`) across existing entities.
3. Expand auth model to support scoped community roles.
4. Create domain service interfaces for search/vector/AI/gamification integrations.
5. Add audit logging on admin endpoints.
6. Add draft/publish lifecycle for lessons.
7. Define event schema for points and skill progression.
8. Create architecture decision records (ADRs) for major tech choices.

This plan keeps the existing monolithic delivery path practical while preparing the platform for reliable multi-community scale, AI-assisted authoring, and rigorous diagnostics-centered pedagogy.
