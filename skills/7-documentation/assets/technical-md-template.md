<!-- Template for docs/TECHNICAL.md, used by the 7-documentation skill. -->

# Technical Reference

**Last updated:** YYYY-MM-DD

## System Overview

<short explanation of runtime shape and major modules>

```mermaid
flowchart LR
  User[User] --> App[App/UI]
  App --> API[API or server actions]
  API --> DB[(Database)]
```

## Architecture

<high-level architecture from PROJ architecture files>

## Technology Choices

| Area | Choice | Why it matters |
|---|---|---|
| Frontend | <tool> | <reason> |
| Data | <tool> | <reason> |

## Data Model

<entities, relationships, ownership, important constraints>

```mermaid
erDiagram
  USER ||--o{ ITEM : owns
```

## Data Flows

### <Flow Name>

<when this flow happens and why>

```mermaid
sequenceDiagram
  actor User
  participant App
  participant API
  participant DB
  User->>App: Action
  App->>API: Request
  API->>DB: Read/write
  API-->>App: Response
```

## Integrations and External Services

<APIs, auth providers, storage, payment, queues, model providers, email, analytics>

## Directory Structure

```text
src/
  app/       - <what lives here>
  features/  - <what lives here>
  lib/       - <what lives here>
```

## Dependencies

<runtime and dev dependencies with purpose, especially newly introduced ones>

## Deployment and Runtime

<provider, build command, env-var overview, persistence/runtime constraints>

## Operational Notes and Gotchas

<source-backed notes from agent.md, QA, post-wave notes, and retrospective>
