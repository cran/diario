#' Store the API token for Diario
#'
#' This function stores the provided authentication token using the `keyring` package.
#' If the token cannot be stored (for example, because the keyring is not accessible),
#' it emits a warning instead of throwing an error, and returns \code{FALSE}.
#'
#' @param token A character string containing the API token to be stored.
#' @return \code{TRUE} (invisibly) if the token was stored successfully;
#'   \code{FALSE} otherwise.
#' @examples
#' \dontrun{
#' # Attempt to store a token:
#' diario_store_token("your-api-token")
#' }
#' @export
diario_store_token <- function(token) {
  # Validate the token argument
  if (!is.character(token) || length(token) != 1L || is.na(token) || !nzchar(token)) {
    cli::cli_abort("{.arg token} must be a valid non-empty string of length 1.")
  }

  # Attempt to store the token
  success <- tryCatch(
    {
      keyring::key_set_with_value(
        service = "DiarioAPI_Token",
        username = "global",
        password = token
      )
      TRUE
    },
    error = function(e) {
      cli::cli_warn(c(
        "Could not store the token.",
        "i" = "Make sure {.pkg keyring} is accessible.",
        "x" = "Underlying error: {conditionMessage(e)}"
      ))
      return(FALSE)
    }
  )

  if (success) {
    cli::cli_alert_success("Token stored successfully.")
  }

  invisible(success)
}

#' Retrieve the API token for Diario
#'
#' This function retrieves the stored authentication token using the `keyring` package.
#' If no valid token (or keyring) is found, it will return `NULL` and (unless
#' `quiet = TRUE`) emit an informational message indicating that no valid token
#' was found.
#'
#' @param quiet A logical flag. If `TRUE`, suppresses the informational message
#'   emitted when no token is found. Default is `FALSE`.
#' @return A character string containing the API token, or `NULL` if no valid token is found.
#' @examples
#' \dontrun{
#' token <- diario_retrieve_token()
#' }
#' @export
diario_retrieve_token <- function(quiet = FALSE) {
  if (!is.logical(quiet) || length(quiet) != 1L || is.na(quiet)) {
    cli::cli_abort("{.arg quiet} must be a single {.code TRUE} or {.code FALSE}.")
  }

  tryCatch(
    {
      # Attempt to retrieve the token
      token <- keyring::key_get(service = "DiarioAPI_Token", username = "global")
      token
    },
    error = function(e) {
      if (!quiet) {
        cli::cli_inform("No valid token found.")
      }
      return(NULL)
    }
  )
}

#' Base URL for the Diario API
#'
#' Returns the base URL used for all Diario API requests. The value can be
#' overridden (for example, to target a staging environment or to mock requests
#' in tests) by setting the `diario.base_url` option.
#'
#' @return A character string with the API base URL, ending in a trailing slash.
#' @keywords internal
#' @noRd
diario_base_url <- function() {
  getOption("diario.base_url", "https://apiexterna.diariodeobra.app/")
}

#' Perform an API request to Diario
#'
#' This function performs an authenticated request to the specified endpoint of the Diario API.
#'
#' @param endpoint A non-empty character string specifying the API endpoint.
#' @param query A named list of query parameters (optional).
#' @param method The HTTP method to use (e.g., "GET", "POST", "PUT", "DELETE"). Default is "GET".
#' @param body A list representing the JSON body for request methods that support a body (e.g., POST).
#' @param verbosity Verbosity level for the request (0 = none, 1 = minimal). Default is 0.
#' @return A list (by default) containing the response from the API. If the content is JSON,
#'   it will be returned as an R object. If not, an error is raised.
#' @examples
#' \dontrun{
#' diario_perform_request("v1/obras", query = list(status = "active"))
#' }
#' @export
diario_perform_request <- function(endpoint,
                                   query = list(),
                                   method = "GET",
                                   body = NULL,
                                   verbosity = 0) {

  # Argument checks
  if (!is.character(endpoint) || length(endpoint) != 1L || is.na(endpoint) || !nzchar(endpoint)) {
    cli::cli_abort("{.arg endpoint} must be a valid non-empty string of length 1.")
  }
  if (!is.character(method) || length(method) != 1L || is.na(method) || !nzchar(method)) {
    cli::cli_abort("{.arg method} must be a valid non-empty string of length 1 (e.g., {.val GET}).")
  }
  valid_methods <- c("GET", "POST", "PUT", "PATCH", "DELETE")
  if (!toupper(method) %in% valid_methods) {
    cli::cli_abort(
      "{.arg method} must be one of {.or {.val {valid_methods}}}."
    )
  }
  if (!is.list(query)) {
    cli::cli_abort("{.arg query} must be a list of query parameters.")
  }
  if (!is.null(body) && !is.list(body)) {
    cli::cli_abort("{.arg body} must be {.code NULL} or a list representing the JSON body.")
  }

  # Retrieve the stored token (quietly; we emit a single, actionable warning below)
  token <- diario_retrieve_token(quiet = TRUE)
  if (is.null(token)) {
    cli::cli_alert_warning(
      "No valid token found. Please store your token with {.fun diario_store_token}."
    )
    return(invisible(NULL))
  }

  # Build the request
  url <- paste0(diario_base_url(), endpoint)
  req <- httr2::request(url) |>
    httr2::req_headers(
      "token" = token,
      "Content-Type" = "application/json"
    )

  # Add query parameters if provided. `req_url_query()` takes individual named
  # arguments via `...`, so the list must be spliced in (not passed as one
  # positional argument).
  if (length(query) > 0) {
    req <- do.call(httr2::req_url_query, c(list(.req = req), query))
  }

  # Attach JSON body if provided
  if (!is.null(body)) {
    req <- req |> httr2::req_body_json(body)
  }

  # Set HTTP method (normalized to upper case, as validated above)
  req <- req |> httr2::req_method(toupper(method))

  # Surface the API's own error message (when available) on HTTP failures
  req <- req |> httr2::req_error(body = diario_error_body)

  # Perform the request
  response <- tryCatch(
    {
      req |> httr2::req_perform(verbosity = verbosity)
    },
    error = function(e) {
      cli::cli_abort(c(
        "Failed to perform the request.",
        "x" = "Underlying error: {conditionMessage(e)}"
      ))
    }
  )

  # An empty body (e.g., a 204 No Content from DELETE) is a valid response
  if (!httr2::resp_has_body(response)) {
    return(invisible(NULL))
  }

  # Handle JSON responses or raise an error otherwise
  ct <- httr2::resp_content_type(response)
  if (grepl("application/json", tolower(ct), fixed = TRUE)) {
    httr2::resp_body_json(response, simplifyVector = TRUE)
  } else {
    cli::cli_abort("Unexpected content type: {.val {ct}}.")
  }
}

#' Extract a human-readable error message from a failed API response
#'
#' Used as the `body` callback for [httr2::req_error()] so that HTTP errors
#' include the message returned by the Diario API, when present.
#'
#' @param resp An [httr2::response] object.
#' @return A character vector with the API error message, or `NULL`.
#' @keywords internal
#' @noRd
diario_error_body <- function(resp) {
  if (!httr2::resp_has_body(resp)) {
    return(NULL)
  }
  ct <- httr2::resp_content_type(resp)
  if (!grepl("application/json", tolower(ct), fixed = TRUE)) {
    return(NULL)
  }
  parsed <- tryCatch(
    httr2::resp_body_json(resp, simplifyVector = TRUE),
    error = function(e) NULL
  )
  # The API typically returns a "message" or "error" field
  msg <- parsed[["message"]]
  if (is.null(msg)) {
    msg <- parsed[["error"]]
  }
  if (is.character(msg) && length(msg) >= 1L) {
    return(msg)
  }
  NULL
}

#' Get company details
#'
#' This function retrieves company details from the Diario API.
#'
#' @return A list containing company details.
#' @examples
#' \dontrun{
#' company <- diario_get_company()
#' }
#' @export
diario_get_company <- function() {
  data <- diario_perform_request("v1/empresa", method = "GET")
  return(data)
}

#' Get all registered entities (cadastros)
#'
#' This function retrieves all registered entities from the Diario API.
#'
#' @return A list containing the entities data.
#' @examples
#' \dontrun{
#' entities <- diario_get_entities()
#' }
#' @export
diario_get_entities <- function() {
  data <- diario_perform_request("v1/cadastros", method = "GET")
  return(data)
}

#' Get list of projects (obras)
#'
#' This function retrieves a list of projects from the Diario API.
#'
#' @return A tibble containing the projects data.
#' @examples
#' \dontrun{
#' projects <- diario_get_projects()
#' }
#' @export
diario_get_projects <- function() {
  data <- diario_perform_request("v1/obras", method = "GET")
  return(tibble::as_tibble(data))
}

#' Get details of a specific project
#'
#' This function retrieves details of a specific project by its ID from the Diario API.
#'
#' @param project_id A valid non-empty string with the project ID.
#' @return A list containing the project details.
#' @examples
#' \dontrun{
#' project <- diario_get_project_details("66face5fe26175e0a904d398")
#' }
#' @export
diario_get_project_details <- function(project_id) {
  if (!is.character(project_id) || length(project_id) != 1L || is.na(project_id) || !nzchar(project_id)) {
    cli::cli_abort("{.arg project_id} must be a valid non-empty string of length 1.")
  }

  data <- diario_perform_request(paste0("v1/obras/", project_id), method = "GET")
  return(data)
}

#' Get the task list of a specific project
#'
#' This function retrieves the task list (schedule, or *cronograma*) of a
#' specific project by its ID. The underlying API wraps the schedule items in a
#' `cronograma` field alongside summary counters; this function returns the
#' schedule items themselves as one row per task.
#'
#' @param project_id A valid non-empty string with the project ID.
#' @return A tibble with one row per schedule item (task). Returns an empty
#'   tibble if the project has no tasks.
#' @examples
#' \dontrun{
#' tasks <- diario_get_task_list("66cf438223aa80386306e647")
#' }
#' @export
diario_get_task_list <- function(project_id) {
  if (!is.character(project_id) || length(project_id) != 1L || is.na(project_id) || !nzchar(project_id)) {
    cli::cli_abort("{.arg project_id} must be a valid non-empty string of length 1.")
  }

  data <- diario_perform_request(
    paste0("v1/obras/", project_id, "/lista-de-tarefas"),
    method = "GET"
  )

  # The API returns summary counters plus a `cronograma` field holding the
  # actual schedule items; return the items as the task list.
  cronograma <- data[["cronograma"]]
  if (is.null(cronograma)) {
    return(tibble::tibble())
  }
  return(tibble::as_tibble(cronograma))
}

#' Get details of a specific task
#'
#' This function retrieves details of a specific task by task ID within a project.
#'
#' @param project_id A valid non-empty string with the project ID.
#' @param task_id A valid non-empty string with the task ID.
#' @return A list containing task details.
#' @examples
#' \dontrun{
#' task <- diario_get_task_details("66cf438223aa80386306e647", "66cf44209e4fedefb306bcd3")
#' }
#' @export
diario_get_task_details <- function(project_id, task_id) {
  if (!is.character(project_id) || length(project_id) != 1L || is.na(project_id) || !nzchar(project_id)) {
    cli::cli_abort("{.arg project_id} must be a valid non-empty string of length 1.")
  }
  if (!is.character(task_id) || length(task_id) != 1L || is.na(task_id) || !nzchar(task_id)) {
    cli::cli_abort("{.arg task_id} must be a valid non-empty string of length 1.")
  }

  data <- diario_perform_request(
    paste0("v1/obras/", project_id, "/lista-de-tarefas/", task_id),
    method = "GET"
  )
  return(data)
}

#' Get reports of a specific project
#'
#' This function retrieves reports of a specific project with optional parameters for limit and order.
#'
#' @param project_id A valid non-empty string with the project ID.
#' @param limit An integer specifying the maximum number of reports to retrieve. Default is 50.
#' @param order A character string specifying the order of the reports (e.g., "asc" or "desc"). Default is "desc".
#' @return A tibble containing the reports.
#' @examples
#' \dontrun{
#' reports <- diario_get_reports("6717f864d163f517ae06e242", limit = 10, order = "asc")
#' }
#' @export
diario_get_reports <- function(project_id, limit = 50, order = "desc") {
  if (!is.character(project_id) || length(project_id) != 1L || is.na(project_id) || !nzchar(project_id)) {
    cli::cli_abort("{.arg project_id} must be a valid non-empty string of length 1.")
  }
  if (!is.numeric(limit) || length(limit) != 1L || is.na(limit) || limit < 1) {
    cli::cli_abort("{.arg limit} must be a positive numeric value of length 1.")
  }
  if (!is.character(order) || length(order) != 1L || !order %in% c("asc", "desc")) {
    cli::cli_abort("{.arg order} must be one of {.or {.val {c('asc', 'desc')}}}.")
  }

  query <- list(limite = limit, ordem = order)
  data <- diario_perform_request(
    paste0("v1/obras/", project_id, "/relatorios"),
    query = query,
    method = "GET"
  )
  return(tibble::as_tibble(data))
}

#' Get details of a specific report
#'
#' This function retrieves details of a specific report by report ID within a project.
#'
#' @param project_id A valid non-empty string with the project ID.
#' @param report_id A valid non-empty string with the report ID.
#' @return A list containing the report details.
#' @examples
#' \dontrun{
#' report <- diario_get_report_details("6717f864d163f517ae06e242", "67648080f0971de9d00324c2")
#' }
#' @export
diario_get_report_details <- function(project_id, report_id) {
  if (!is.character(project_id) || length(project_id) != 1L || is.na(project_id) || !nzchar(project_id)) {
    cli::cli_abort("{.arg project_id} must be a valid non-empty string of length 1.")
  }
  if (!is.character(report_id) || length(report_id) != 1L || is.na(report_id) || !nzchar(report_id)) {
    cli::cli_abort("{.arg report_id} must be a valid non-empty string of length 1.")
  }

  data <- diario_perform_request(
    paste0("v1/obras/", project_id, "/relatorios/", report_id),
    method = "GET"
  )
  return(data)
}
