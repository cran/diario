#' Store the API token for Diario
#'
#' This function stores the provided authentication token using the `keyring` package.
#' If the token cannot be stored (for example, because the keyring is not accessible),
#' it prints a message instead of throwing an error, and returns \code{FALSE}.
#'
#' @param token A character string containing the API token to be stored.
#' @return \code{TRUE} (invisibly) if the token was stored successfully;
#'   \code{FALSE} otherwise.
#' @examples
#' # Attempt to store a token:
#' diario_store_token("your-api-token")
#' @export
diario_store_token <- function(token) {
  # Validate the token argument
  if (!is.character(token) || length(token) != 1L || !nzchar(token)) {
    stop("`token` must be a valid non-empty string of length 1.")
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
      message(
        "Could not store the token. Make sure `keyring` is accessible.\n",
        "Underlying error: ", conditionMessage(e)
      )
      return(FALSE)
    }
  )

  if (success) {
    message("Token stored successfully.")
  }

  invisible(success)
}

#' Retrieve the API token for Diario
#'
#' This function retrieves the stored authentication token using the `keyring` package.
#' If no valid token (or keyring) is found, it will return `NULL` and print a message
#' in English indicating that no valid token was found.
#'
#' @return A character string containing the API token, or `NULL` if no valid token is found.
#' @examples
#' token <- diario_retrieve_token()
#' @export
diario_retrieve_token <- function() {
  tryCatch(
    {
      # Attempt to retrieve the token
      token <- keyring::key_get(service = "DiarioAPI_Token", username = "global")
      token
    },
    error = function(e) {
      message("No valid token found.")
      return(NULL)
    }
  )
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
  if (!is.character(endpoint) || length(endpoint) != 1L || !nzchar(endpoint)) {
    stop("`endpoint` must be a valid non-empty string of length 1.")
  }
  if (!is.character(method) || length(method) != 1L || !nzchar(method)) {
    stop("`method` must be a valid non-empty string of length 1 (e.g., 'GET').")
  }
  valid_methods <- c("GET", "POST", "PUT", "PATCH", "DELETE")
  if (!toupper(method) %in% valid_methods) {
    stop(
      "`method` must be one of: ",
      paste(valid_methods, collapse = ", "), "."
    )
  }
  if (!is.list(query)) {
    stop("`query` must be a list of query parameters.")
  }
  if (!is.null(body) && !is.list(body)) {
    stop("`body` must be NULL or a list representing the JSON body.")
  }

  # Retrieve the stored token
  token <- diario_retrieve_token()
  if (is.null(token)) {
    message("No valid token found. Please store your token with `diario_store_token()`.")
    return(invisible(NULL))
  }

  # Build the request
  base_url <- "https://apiexterna.diariodeobra.app/"
  url <- paste0(base_url, endpoint)
  req <- httr2::request(url) |>
    httr2::req_headers(
      "token" = token,
      "Content-Type" = "application/json"
    )

  # Add query parameters if provided
  if (length(query) > 0) {
    req <- req |> httr2::req_url_query(query)
  }

  # Attach JSON body if provided
  if (!is.null(body)) {
    req <- req |> httr2::req_body_json(body)
  }

  # Set HTTP method
  req <- req |> httr2::req_method(method)

  # Perform the request
  response <- tryCatch(
    {
      req |> httr2::req_perform(verbosity = verbosity)
    },
    error = function(e) {
      stop("Failed to perform the request.\nUnderlying error: ", conditionMessage(e))
    }
  )

  # Handle JSON responses or raise an error otherwise
  ct <- httr2::resp_content_type(response)
  if (grepl("application/json", tolower(ct), fixed = TRUE)) {
    httr2::resp_body_json(response, simplifyVector = TRUE)
  } else {
    stop("Unexpected content type: ", ct)
  }
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
#' projects <- diario_get_projects(query = list(status = "active"))
#' }
#' @export
diario_get_projects <- function() {
  # if (!is.list(query)) {
  #   stop("`query` must be a list of query parameters.")
  # }
  data <- diario_perform_request("v1/obras",  method = "GET")
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
  if (!is.character(project_id) || length(project_id) != 1L || !nzchar(project_id)) {
    stop("`project_id` must be a valid non-empty string of length 1.")
  }

  data <- diario_perform_request(paste0("v1/obras/", project_id), method = "GET")
  return(data)
}

#' Get the task list of a specific project
#'
#' This function retrieves the task list of a specific project by its ID.
#'
#' @param project_id A valid non-empty string with the project ID.
#' @return A tibble containing the task list.
#' @examples
#' \dontrun{
#' tasks <- diario_get_task_list("66cf438223aa80386306e647")
#' }
#' @export
diario_get_task_list <- function(project_id) {
  if (!is.character(project_id) || length(project_id) != 1L || !nzchar(project_id)) {
    stop("`project_id` must be a valid non-empty string of length 1.")
  }

  data <- diario_perform_request(
    paste0("v1/obras/", project_id, "/lista-de-tarefas"),
    method = "GET"
  )
  return(tibble::as_tibble(data))
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
  if (!is.character(project_id) || length(project_id) != 1L || !nzchar(project_id)) {
    stop("`project_id` must be a valid non-empty string of length 1.")
  }
  if (!is.character(task_id) || length(task_id) != 1L || !nzchar(task_id)) {
    stop("`task_id` must be a valid non-empty string of length 1.")
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
  if (!is.character(project_id) || length(project_id) != 1L || !nzchar(project_id)) {
    stop("`project_id` must be a valid non-empty string of length 1.")
  }
  if (!is.numeric(limit) || length(limit) != 1L || limit < 1) {
    stop("`limit` must be a positive numeric value of length 1.")
  }
  if (!is.character(order) || length(order) != 1L || !nzchar(order)) {
    stop("`order` must be a valid non-empty string of length 1 (e.g., 'asc' or 'desc').")
  }

  query <- list(limite = limit, ordem = order)
  data <- diario_perform_request(
    paste0("v1/obras/", project_id, "/relatorios"),
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
  if (!is.character(project_id) || length(project_id) != 1L || !nzchar(project_id)) {
    stop("`project_id` must be a valid non-empty string of length 1.")
  }
  if (!is.character(report_id) || length(report_id) != 1L || !nzchar(report_id)) {
    stop("`report_id` must be a valid non-empty string of length 1.")
  }

  data <- diario_perform_request(
    paste0("v1/obras/", project_id, "/relatorios/", report_id),
    method = "GET"
  )
  return(data)
}
