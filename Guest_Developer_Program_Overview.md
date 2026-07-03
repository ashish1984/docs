# What Is the Guest Developer Program in Azure Databricks?

## Overview

The **Guest Developer Program** is the NextGenBI platform's structured process for bringing non-employee contributors — vendor engineers, contractors, hackathon collaborators, or short-term project resources — onto the Azure Databricks platform, giving them exactly the access they need to do their job, and ensuring their work and knowledge stay on the platform after they leave.

It exists because of a recurring pattern on this platform: a guest is onboarded to deliver something, they build it, they leave — and the access, the artifacts, and the knowledge they created don't leave cleanly with them. What's left behind is orphaned Unity Catalog grants, undocumented notebooks, forgotten personal access tokens, and schemas nobody is confident are safe to remove.

The program's core principle:

> **Guests build. The Platform owns the risk.** Every privilege granted to a guest is a liability the Platform Lead carries after the guest is gone.

Guest access is temporary by design — access is not open-ended, and it doesn't outlive the reason it was granted.

---

## Why It Exists

| Problem on the platform | What the program does about it |
|---|---|
| Guests leave without documentation | Handoff package is mandatory and blocks offboarding sign-off |
| Access outlives the engagement | Every grant has a hard end date tied to the engagement |
| Nobody knows who owns what a guest built | Ownership is reassigned to an internal engineer at offboarding |
| Orphaned credentials and dormant grants | Access is issued via group membership, so revocation is a single action, plus a 30-day post-offboarding sweep |
| Vendors self-provision secrets/credentials | Secret scopes and service principals are Platform Admin-owned, never guest self-service |

---

## The Three Guest Personas

Access is never one-size-fits-all. Every guest is assigned the narrowest persona that lets them do their job:

- **Explorer / Analyst** — Read-only access for investigation or scoping. No compute creation, no write access.
- **Contributor** — Time-boxed write access to a named sandbox in Dev, under supervision of an internal engineer.
- **Builder / Developer** — Full Dev sandbox access for an end-to-end build (e.g. a vendor engagement or hackathon project). Prod access is never granted to any guest persona, regardless of tier.

---

## The Guest Lifecycle

1. **Pre-onboarding** — A sponsor is named, scope of work is documented, and a hard end date is set *before* any credential is issued. Default access is Dev-only.
2. **Active engagement** — Guest works under platform standards: DABs branching flow, secret hygiene (Key Vault-backed scopes only), Unity Catalog naming conventions, and clear ownership tagging on everything created.
3. **Handoff** — Before offboarding, the guest's sponsor collects a handoff package: architecture summary, README, runbook, full object inventory, and a live knowledge-transfer session. This is a gate, not a courtesy — offboarding doesn't close without it.
4. **Offboarding** — The Platform Lead removes the guest's AAD group membership (cascading all Unity Catalog grants), rotates any credentials the guest touched, reassigns ownership of created objects, and runs a dormant-grant sweep 30 days later.

---

## What Guests Can Never Do

Regardless of persona or engagement length, guests never:

- Get Production access, under any circumstance
- Hold Metastore or Account Admin rights
- Self-provision secret scopes or service principal credentials
- Remain the sole owner of any object other teams depend on

---

## How This Is Enforced

The program isn't a policy that relies on guest goodwill — it's backed by continuous automated checks for:

- Vendor/service-principal lifecycle (flags identities active past engagement end date)
- Personal access tokens in pipelines
- PAT age and rotation compliance
- Dormant Unity Catalog grants
- Cross-environment (Dev/UAT → Prod) leakage
- Unusual grant velocity to a single guest identity

---

## Related Documents

- **Guest Developer Governance Standard** — the full policy: access rules, technical standards, RACI, and exceptions process
- **Guest Onboarding Package Checklist** — the working tracker for assembling and delivering onboarding materials to each guest

---
*Owner: Tech Lead, Data Engineering (DTS) — NextGenBI Platform*
