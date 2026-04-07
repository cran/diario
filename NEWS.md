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
