# Fix prompts

This branch is the base for the six hardware-suite failures. It already
contains the suite. Each file in this directory is the whole assignment
for one agent.

Start a new branch from `cursor/hw-fix-base-854d`. Do not commit on this
branch. Fix only the issue named in your file, then open a pull request
into this branch.

## Generators

These four files belong to [`../generators_plan.md`](../generators_plan.md),
not to the hardware-fix assignment above.

| File | Role |
| --- | --- |
| [`generators_tester.md`](generators_tester.md) | Oracle goldens and `xfail` entries. Lands first |
| [`generators_implementer_yield.md`](generators_implementer_yield.md) | Generator objects and `yield` |
| [`generators_implementer_delegate.md`](generators_implementer_delegate.md) | `yield from`, after yield has landed |
| [`generators_critic.md`](generators_critic.md) | Compare the result with the oracle |
