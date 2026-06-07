# Smart Patient Summary Agent for FHIR

An AI agent built on InterSystems IRIS AI Hub that generates role-specific clinical summaries from FHIR patient data. Given a patient ID, it queries a FHIR R4 server, extracts structured clinical signals, and produces four distinct narrative summaries tailored to:

- **ED Doctor** — safety-first, immediate action priorities, disposition context
- **Care Manager** — continuity gaps, transitions, care coordination tasks
- **Patient** — plain language, self-care guidance, warning signs
- **Family Caregiver** — monitoring checkpoints, medication safety, escalation triggers

Output is deterministic and evidence-based — same FHIR data, four different narrative framings.

## Team

- Gil Tavassy — [Developer Community profile](https://community.intersystems.com/user/gil-tavassy) · [LinkedIn](https://www.linkedin.com/in/gil-tavassy-5703b311b)

Submission mode: solo project.

## Architecture

Two containers work together:

| Container | Image | Purpose |
|---|---|---|
| `fhir` | `intersystemsdc/irishealth-community:latest` | FHIR R4 server — stores and serves patient data |
| `iris` | `irishealth-community:2026.2.0AI.162.0` (AI Hub EAP) | Runs the ObjectScript summary engine |

The `iris` container connects to the `fhir` container over Docker's internal network.

## Prerequisites

- **Docker Desktop** (Windows / Mac) or Docker Engine (Linux)
- **InterSystems IRIS AI Hub EAP image** — the AI Hub is baked into this image.
  1. Register / log in at https://evaluation.intersystems.com/Eval/early-access/AIHub and select the **AI Hub** program.
  2. Download **two files**:
     - `irishealth-community-2026.2.0AI.162.0-docker.tar.gz` (x64) — or the `arm64` variant for Mac M-series
     - `iris-container-x64.key` (or `iris-container-arm64.key` for ARM64)
  3. Load and tag the image (one-time step per machine):
     ```
     docker image load -i irishealth-community-2026.2.0AI.162.0-docker.tar.gz
     docker tag docker.iscinternal.com/docker-intersystems/intersystems/irishealth-community:2026.2.0AI.162.0 irishealth-community:2026.2.0AI.162.0
     ```

## Quick start

1. Clone this repository.
2. Copy your `iris-container-x64.key` into the `keys/` folder at the repo root.
3. Build and start both containers:
   ```
   docker compose build
   docker compose up -d
   ```
4. Wait ~60 seconds for both containers to become healthy.
5. Load patient data into the FHIR server (see [Patient data](#patient-data) below).
6. Run a summary.

## Patient data

The summary engine requires at least one patient in the `fhir` container's FHIR R4 server (`http://localhost:52775/fhir/r4`).

**Load with any FHIR R4 client** (Postman, HAPI FHIR CLI, curl) or generate realistic synthetic profiles with [Synthea](https://github.com/synthetichealth/synthea).

The FHIR server is accessible on the host at `http://localhost:52775/fhir/r4`. The `iris` container reaches it internally at `http://fhir:52773/fhir/r4`.

**Note the patient ID** returned when you POST the Patient resource — you'll use it in the demo commands below.

## Running a summary

Replace `<patientId>` with your patient's FHIR ID:

```bash
# All four roles, detailed mode
docker exec smart-patient-summary-generator-iris-1 bash -c \
  "printf 'Do ##class(Sample.AI.Examples.FHIRSummary).DemoNarrativeAllRoles(\"<patientId>\",\"detailed\")\nHalt\n' \
  | iris session IRIS -U USER 2>&1 | grep -Ev '^(USER>|Node:)'"

# Single role (ed, care_manager, patient, or caregiver)
docker exec smart-patient-summary-generator-iris-1 bash -c \
  "printf 'Do ##class(Sample.AI.Examples.FHIRSummary).DemoNarrative(\"<patientId>\",\"ed\",\"detailed\")\nHalt\n' \
  | iris session IRIS -U USER 2>&1 | grep -Ev '^(USER>|Node:)'"

# Brief mode (2 items per section)
docker exec smart-patient-summary-generator-iris-1 bash -c \
  "printf 'Do ##class(Sample.AI.Examples.FHIRSummary).DemoNarrativeAllRoles(\"<patientId>\",\"brief\")\nHalt\n' \
  | iris session IRIS -U USER 2>&1 | grep -Ev '^(USER>|Node:)'"
```

## All entry points

| Method | Description |
|---|---|
| `FHIRSummary.DemoNarrativeAllRoles(patientId, detailMode)` | Four-role narrative — recommended starting point |
| `FHIRSummary.DemoNarrative(patientId, role, detailMode)` | Single role narrative (`ed`, `care_manager`, `patient`, `caregiver`) |
| `FHIRSummary.DemoDeterministic(patientId, role, detailMode)` | Single role as JSON |
| `FHIRSummary.DemoRoleComparison(patientId, detailMode)` | All roles as JSON |
| `FHIRSummary.DemoNarrativeToFile(patientId, role, detailMode, path)` | Write narrative to file |

`detailMode`: `"brief"` (2 items/section) or `"detailed"` (full evidence).

## Environment variables

Override before `docker compose up` to connect to an external FHIR server:

| Variable | Default | Purpose |
|---|---|---|
| `FHIR_BASE_URL` | `http://fhir:52773/fhir/r4` | FHIR R4 endpoint |
| `FHIR_BASIC_USER` | `_SYSTEM` | Basic auth username |
| `FHIR_BASIC_PASS` | `SYS` | Basic auth password |
| `FHIR_BEARER_TOKEN` | _(none)_ | Bearer token (alternative to basic auth) |

## FHIR resources used

The engine queries: `Patient`, `Observation`, `AllergyIntolerance`, `Condition`, `MedicationRequest`, `Encounter`, `CarePlan`.

## Output structure

Each role summary contains:

- **Patient Overview** — demographics and evidence inventory
- **Clinical Details** — conditions, medications, allergies, encounters, observations, care plans
- **Current Issues** — deterministic extraction of active problems, abnormal findings, alerts
- **Recent Changes** — trend signals and data freshness
- **Risks / Follow-up** — evidence-based escalation triggers
- **Role-Specific Action Plan** — immediate priorities, weekly actions, escalation criteria

## What is the AI Hub?

InterSystems AI Hub is the AI SDK for IRIS — it provides ObjectScript, Python, and Java APIs for building agents, tool-based pipelines, and RAG applications that run natively on IRIS.

- [ObjectScript SDK guide](ObjectScript_SDK_Guide.md)
- [Advanced features](ObjectScript_SDK_Advanced.md)
- [Examples](ObjectScript_SDK_Examples.md)
- [MCP Server guide](MCP_Server_Guide.md)
- [LangChain guide](langchain_SDK.md)
- [Config Store guide](Config_Store_Guide.md)
