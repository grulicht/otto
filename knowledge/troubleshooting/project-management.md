# Project Management Tool Troubleshooting

## Jira JQL Not Returning Expected Results
**Symptoms:** Filters missing issues, wrong count, unexpected empty results.
**Steps:**
1. Verify field names: use autocomplete in Jira's advanced search to confirm field IDs
2. Check text search: use `text ~ "keyword"` not `= "keyword"` for text fields
3. Custom fields require their exact ID: `cf[10001]` format
4. Check project permissions: JQL respects the user's access level
5. Use `ORDER BY` to verify results are not just sorted differently
6. Empty/null check: use `field is EMPTY` not `field = ""`
7. Date formats: use `"2024-01-15"` or relative (`-1w`, `startOfMonth()`)
8. Escape special characters in JQL: quote values containing spaces or operators

## Jira Webhook Failures
**Symptoms:** Events not triggering webhooks, delayed delivery, 4xx/5xx errors in webhook logs.
**Steps:**
1. Check webhook configuration: Settings > System > Webhooks
2. Verify URL is publicly accessible (Jira Cloud cannot reach localhost or private IPs)
3. Check JQL filter on webhook: overly restrictive filters silently drop events
4. Review webhook logs for HTTP status codes and response bodies
5. Ensure endpoint responds within timeout (10 seconds for Jira Cloud)
6. Check for SSL certificate issues on the receiving endpoint
7. Verify the events checkbox list matches the events you expect
8. For rate limiting: Jira may batch or delay webhooks under load

## Confluence Page Permission Issues
**Symptoms:** Users cannot view/edit pages, permission errors, space access denied.
**Steps:**
1. Check space permissions: Space Settings > Permissions
2. Page restrictions override space permissions: check page-level restrictions
3. Inherited restrictions from parent pages can block access
4. Group membership: verify user is in the expected groups
5. Anonymous access: check if space allows anonymous viewing
6. Admin override: space admins can always access; verify admin group
7. Check if page is in a personal space (only owner has default access)
8. Use bulk permission audit: Confluence admin > Space permissions matrix

## Linear API Rate Limiting
**Symptoms:** 429 responses, slow webhook processing, batch operations failing.
**Steps:**
1. Check rate limit headers: `X-RateLimit-Remaining`, `X-RateLimit-Reset`
2. Linear allows ~250 requests per minute per API key
3. Implement exponential backoff on 429 responses
4. Use GraphQL batching: combine multiple queries into one request
5. Use pagination with `after` cursor instead of offset-based pagination
6. Cache frequently accessed data (teams, labels, states) locally
7. Use webhooks instead of polling for real-time updates
8. For bulk operations: use Linear's bulk mutation endpoints

## Notion Integration Sync Issues
**Symptoms:** Pages not syncing, stale data, integration cannot access database.
**Steps:**
1. Verify integration has access: Share page/database with the integration
2. Check API version header: `Notion-Version: 2022-06-28` (use latest stable)
3. Notion API has 3 requests/second rate limit: implement throttling
4. Database properties may change: always handle missing/renamed properties
5. Rich text blocks have a 2000-character limit per block
6. Pagination: always check `has_more` and use `start_cursor` for next page
7. Check if page is in a workspace the integration has access to
8. For sync: store `last_edited_time` and filter with `filter.timestamp`

## Cross-Tool Synchronization Problems (Jira<->GitHub, Linear<->GitLab)
**Symptoms:** Issues out of sync, duplicate items, status mismatch, broken links.
**Steps:**
1. Check webhook delivery logs on both sides for failures
2. Verify field mapping: status names often differ between tools
3. Implement idempotency: use external IDs to prevent duplicates
4. Handle race conditions: two-way sync can create loops without guard logic
5. Use dedicated sync tools (Unito, Exalate, Polytomic) for complex mappings
6. Log all sync operations for debugging: source event, mapped action, result
7. Set up dead-letter queue for failed sync events
8. Test with a single project before rolling out organization-wide
