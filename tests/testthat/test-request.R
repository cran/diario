# Tests for the request layer. The network is mocked with httr2's own
# `with_mocked_responses()`, and the token lookup is stubbed so these tests
# never touch keyring or the real API.

test_that("diario_base_url() honours the diario.base_url option", {
  withr::local_options(diario.base_url = "https://staging.example/")
  expect_equal(diario_base_url(), "https://staging.example/")
})

test_that("diario_base_url() defaults to the production API", {
  withr::local_options(diario.base_url = NULL)
  expect_match(diario_base_url(), "diariodeobra", fixed = TRUE)
})

test_that("diario_perform_request() returns parsed JSON on success", {
  testthat::local_mocked_bindings(
    diario_retrieve_token = function(quiet = FALSE) "fake-token"
  )
  mock <- function(req) {
    httr2::response(
      status_code = 200,
      headers = list("Content-Type" = "application/json"),
      body = charToRaw('{"nome":"Empresa A"}')
    )
  }
  result <- httr2::with_mocked_responses(mock, {
    diario_perform_request("v1/empresa")
  })
  expect_equal(result$nome, "Empresa A")
})

test_that("diario_perform_request() returns NULL on an empty body", {
  testthat::local_mocked_bindings(
    diario_retrieve_token = function(quiet = FALSE) "fake-token"
  )
  mock <- function(req) httr2::response(status_code = 204)
  result <- httr2::with_mocked_responses(mock, {
    diario_perform_request("v1/empresa", method = "DELETE")
  })
  expect_null(result)
})

test_that("diario_perform_request() returns NULL when no token is stored", {
  testthat::local_mocked_bindings(
    diario_retrieve_token = function(quiet = FALSE) NULL
  )
  expect_null(suppressMessages(diario_perform_request("v1/empresa")))
})

test_that("query parameters are spliced into the request URL", {
  testthat::local_mocked_bindings(
    diario_retrieve_token = function(quiet = FALSE) "fake-token"
  )
  seen_url <- NULL
  mock <- function(req) {
    seen_url <<- req$url
    httr2::response(
      status_code = 200,
      headers = list("Content-Type" = "application/json"),
      body = charToRaw("[]")
    )
  }
  httr2::with_mocked_responses(mock, {
    diario_get_reports("abc", limit = 3, order = "asc")
  })
  expect_match(seen_url, "limite=3", fixed = TRUE)
  expect_match(seen_url, "ordem=asc", fixed = TRUE)
})

test_that("diario_get_projects() returns a tibble", {
  testthat::local_mocked_bindings(
    diario_retrieve_token = function(quiet = FALSE) "fake-token"
  )
  mock <- function(req) {
    httr2::response(
      status_code = 200,
      headers = list("Content-Type" = "application/json"),
      body = charToRaw('[{"nome":"A"},{"nome":"B"}]')
    )
  }
  result <- httr2::with_mocked_responses(mock, {
    diario_get_projects()
  })
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 2L)
})

test_that("diario_get_task_list() returns the cronograma items", {
  testthat::local_mocked_bindings(
    diario_retrieve_token = function(quiet = FALSE) "fake-token"
  )
  mock <- function(req) {
    httr2::response(
      status_code = 200,
      headers = list("Content-Type" = "application/json"),
      body = charToRaw(paste0(
        '{"totalTarefas":2,"cronograma":[',
        '{"_id":"t1","descricao":"A"},',
        '{"_id":"t2","descricao":"B"}]}'
      ))
    )
  }
  result <- httr2::with_mocked_responses(mock, {
    diario_get_task_list("abc")
  })
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 2L)
  expect_equal(result[["_id"]], c("t1", "t2"))
})

test_that("diario_get_task_list() returns an empty tibble when no schedule", {
  testthat::local_mocked_bindings(
    diario_retrieve_token = function(quiet = FALSE) "fake-token"
  )
  mock <- function(req) {
    httr2::response(
      status_code = 200,
      headers = list("Content-Type" = "application/json"),
      body = charToRaw('{"totalTarefas":0}')
    )
  }
  result <- httr2::with_mocked_responses(mock, {
    diario_get_task_list("abc")
  })
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0L)
})

test_that("diario_error_body() extracts the API error message", {
  resp <- httr2::response(
    status_code = 400,
    headers = list("Content-Type" = "application/json"),
    body = charToRaw('{"message":"Token invalido"}')
  )
  expect_equal(diario_error_body(resp), "Token invalido")
})

test_that("diario_error_body() returns NULL for empty or non-JSON bodies", {
  expect_null(diario_error_body(httr2::response(status_code = 204)))
  expect_null(
    diario_error_body(
      httr2::response(
        status_code = 500,
        headers = list("Content-Type" = "text/html"),
        body = charToRaw("<html></html>")
      )
    )
  )
})
