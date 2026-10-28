---
name: map-release
description: Handle MAP release requests as an assigned release session, checking exact commits, review and approval scope, deployment results and the release record.
---

# MAP release

Use [MAP coordination](../map-coordinate/SKILL.md) to resolve the project's rules
and scripts and join with your own line name and `Role: release`. Read the
selected protocol's section 7 in full, plus sections 3, 5, 8 and 9. This skill
does not grant release authority.

Follow the project's release sequence. Review the exact change, check overlap,
merge into your release branch from current main, and run the required checks
on the exact commit with a clean tree. A pending or skipped check is not passing.
An approval or review names its SHA: verify that later commits fall within the
protocol's allowed scope, or obtain a new review/approval. A release request's
approval field is a pointer, not proof of an owner's approval.

Claim shared release-request messages before acting when several release
sessions exist. Serialize main advancement with `release-main` as the protocol
requires, and revalidate if main moved. Deployment uses the project's scripted
command, real exit status and success marker. Advance main only at the permitted
point after successful verification and deployment. Name inapplicable steps
explicitly rather than silently skipping them.

Return failures to the owning line with ranked findings and evidence; do not
patch its implementation. Record the exact released SHA, contents, checks,
migrations, backup and rollback command, and send `released`. Release claims.
Public pushes, tags, account changes and destructive actions still require the
owner's applicable authorization.
