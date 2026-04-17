# Zero-Downtime Database Migration Pattern

## The Expand-Contract Pattern

For schema changes that would break existing code, use the expand-contract
(also called parallel change) pattern:

### Phase 1: Expand
Add new column/table alongside existing one.
Both old and new versions of the application work.

```sql
-- Add new column (nullable, no default required)
ALTER TABLE users ADD COLUMN email_normalized VARCHAR(255);
```

### Phase 2: Migrate
Backfill data from old to new format.
Run in batches to avoid locking.

```sql
-- Backfill in batches
UPDATE users SET email_normalized = LOWER(email)
WHERE email_normalized IS NULL
LIMIT 1000;
```

### Phase 3: Transition
Deploy application code that writes to both old and new.
Reads from new column.

### Phase 4: Contract
Remove old column once all code uses the new one.

```sql
ALTER TABLE users DROP COLUMN email;
```

## Rules for Zero-Downtime Migrations
1. Never rename columns directly (expand-contract instead)
2. Never drop columns that running code uses
3. Add columns as nullable or with defaults
4. Add indexes concurrently (`CREATE INDEX CONCURRENTLY` in PostgreSQL)
5. Test migrations against production-sized data
6. Run migrations before deploying code that depends on them
7. Make migrations backward compatible (old code must still work)

## Anti-Patterns
- Running `ALTER TABLE ... ADD COLUMN ... NOT NULL` on large tables (locks table)
- Dropping columns before removing code references
- Running long data migrations in a single transaction
- Not testing migration rollback
