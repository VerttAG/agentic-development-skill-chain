<!-- Template for the feature source folder agent.md (long-term memory), used by the 5-executing skill. -->

# Agent Notes — [Feature Name]

## Gotchas

### Supabase RLS blocks server actions without explicit role claim
Discovered during US-4 (activate delivery). Server actions run as `anon` unless
`set role authenticated` is called explicitly. Workaround: call `supabase.auth.getUser()`
at the top of every mutating server action before any DB write.

### Zod refinements don't run on optional fields when undefined
If a field is optional and undefined, `.refine()` is skipped entirely.
Use `.optional().refine()` vs `.refine()` on the base type — different behavior.

## Patterns That Work Well
...

## Dead Ends (don't try these again)
...
