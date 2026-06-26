# diario 0.1.2

## Bug fixes

* Fixed a bug where query parameters were passed to `httr2::req_url_query()`
  as a single list argument, which errored out ("All components of `...` must
  be named"). They are now spliced in correctly, so `diario_get_reports()`'s
  `limit`/`order` arguments work as documented.

* All argument validators now reject missing values (`NA`). Previously
  `nzchar(NA)` returned `TRUE`, so an `NA` token could be passed straight to
  `keyring`, and `NA` ids could be pasted into request URLs.

## Potentially breaking changes

* `diario_get_task_list()` now returns the schedule items (one row per task,
  with `_id`, `descricao`, etc.) instead of the raw API envelope. Previously
  the summary counters were recycled across rows and the actual tasks were
  hidden inside a nested `cronograma` column.

## Improvements

* `diario_perform_request()` now sends the HTTP method in upper case, matching
  the validation, so lower-case input (e.g. `"get"`) no longer leaks through.

* The API base URL is now configurable via the `diario.base_url` option,
  making it possible to target staging environments or mock requests in tests.

* HTTP errors now surface the message returned by the Diario API (via
  `httr2::req_error()`), and empty response bodies (e.g. `204 No Content`
  from `DELETE`) are handled gracefully instead of raising a content-type
  error.

* `diario_get_reports()` now validates that `order` is one of `"asc"` or
  `"desc"` up front.

* `diario_retrieve_token()` gained a `quiet` argument; `diario_perform_request()`
  uses it to avoid emitting a duplicate "No valid token found" message.

* Added a `testthat` test suite covering argument validation and the request
  layer (network mocked with `httr2::with_mocked_responses()`).

# diario 0.1.1

## Improvements

* Migrated all user-facing messages, warnings, and errors to use the `cli`
  package (`cli::cli_abort()`, `cli::cli_warn()`, `cli::cli_inform()`,
  `cli::cli_alert_success()`, `cli::cli_alert_warning()`), replacing base R
  `stop()` and `message()` calls. This provides richer, more informative
  output with inline markup for arguments, values, functions, and packages.

* Fixed a bug in `diario_get_reports()` where query parameters (`limite`,
  `ordem`) were constructed but never passed to `diario_perform_request()`.

* Fixed incorrect example in `diario_get_projects()` documentation that
  referenced a `query` parameter not accepted by the function.

* Wrapped `diario_store_token()` and `diario_retrieve_token()` examples in
 `\dontrun{}` to avoid CRAN check failures on systems without keyring support.

* Removed `LazyData: true` from DESCRIPTION (no `data/` directory exists).

* Added `BugReports` field to DESCRIPTION.

* Updated authors list.

# diario 0.1.0

* Initial CRAN release.
* Token management via `keyring` (`diario_store_token()`,
  `diario_retrieve_token()`).
* Authenticated API requests with `httr2` (`diario_perform_request()`).
* Convenience wrappers: `diario_get_company()`, `diario_get_entities()`,
  `diario_get_projects()`, `diario_get_project_details()`,
  `diario_get_task_list()`, `diario_get_task_details()`,
  `diario_get_reports()`, `diario_get_report_details()`.
