# Mobile development workflow

Read `README.md`, `CONTEXT.md`, and relevant contracts under `docs/specs/` for the customer mobile app's scope and terminology.

## Keep KanbanFlow current

The user requires updates to [the GetPrio KanbanFlow board](https://kanbanflow.com/board/29wNuqR) whenever significant mobile app changes are made. Updating the board is part of completing the development task.

- Significant changes include customer-visible features or behavior, meaningful bug fixes, authentication/security changes, API integration or lifecycle changes, release milestones, and changes to scope or dependencies. Batch related small edits into the relevant card update.
- Read the current board before editing. Update the matching card rather than duplicating it; create a mobile-scoped card if no suitable card exists. Preserve unrelated cards and user edits. Do not clear or rebuild the board unless explicitly requested again.
- Keep task descriptions, acceptance criteria, dependencies, estimates, labels, and workflow status aligned with the actual work. Record a concise summary and available verification evidence or commit/PR references. Do not invent time spent, test results, or completion evidence.
- Use `Mobile`, the appropriate work-area label, and the relevant sprint label. Current colors are Yellow for UI, Blue for API Integration, Purple for Security, Cyan for Native/Setup, Orange for QA, and Green for Release; preserve later user changes to this scheme.
- Plan one-week sprints with 20 hours of capacity: normally 16 estimated task hours and 4 hours for review, fixes, and spillover. Sprint labels represent sequence, not fixed calendar dates. Reassess estimates and sprint placement when scope changes; do not silently overfill a sprint.
- Use Product Backlog for future work, Sprint Backlog for selected sprint work, In Progress for active work, and Done only when the card's mobile acceptance criteria are implemented and verified. Partial work remains open with remaining work stated clearly. Web/backend completion alone is not mobile completion; build/upload alone is not TestFlight availability.
- Routine board updates associated with significant mobile changes are authorized by this standing instruction; no repeated confirmation is needed. If board access is unavailable, report the blocker and the exact pending updates instead of claiming synchronization succeeded.
- Include a brief KanbanFlow update summary or access blocker in the final development report.
