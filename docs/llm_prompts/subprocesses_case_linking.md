**Prompt:** How do you link subprocesses modeled as separate cases?

**Abstract:** In TimeMolecules, subprocesses should be modeled as independent cases with their own CaseID. When a parent case triggers a subprocess, the child case carries explicit linking information through case properties: `CallingCaseID` (references the parent CaseID), `CallingEvent` (name of the triggering event), and `CallingEventDateTime` (timestamp when the subprocess was called).

This design keeps the data model clean and event-centric while maintaining full traceability. It allows each subprocess (e.g., kitchen preparation in a restaurant) to be analyzed separately, yet still connected back to the parent process (e.g., dining room experience). The pattern creates clear function-like behavior where one case can "call" another and later resume based on the child case completion.

**Primary Location:** https://github.com/MapRock/TimeMolecules/blob/main/docs/subprocess_case_linking.md
