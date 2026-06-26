# Input-validation tests. These exercise the argument checks that run *before*
# any network access or token retrieval, so they need no API token or mock.

test_that("diario_store_token() rejects invalid tokens", {
  expect_error(diario_store_token(123), "token")
  expect_error(diario_store_token(c("a", "b")), "token")
  expect_error(diario_store_token(""), "token")
  expect_error(diario_store_token(NA_character_), "token")
})

test_that("diario_retrieve_token() validates 'quiet'", {
  expect_error(diario_retrieve_token(quiet = "yes"), "quiet")
  expect_error(diario_retrieve_token(quiet = NA), "quiet")
  expect_error(diario_retrieve_token(quiet = c(TRUE, FALSE)), "quiet")
})

test_that("diario_perform_request() validates its arguments", {
  expect_error(diario_perform_request(""), "endpoint")
  expect_error(diario_perform_request(123), "endpoint")
  expect_error(diario_perform_request("v1/obras", method = "FETCH"), "method")
  expect_error(diario_perform_request("v1/obras", method = ""), "method")
  expect_error(diario_perform_request("v1/obras", query = "status=1"), "query")
  expect_error(diario_perform_request("v1/obras", body = "not-a-list"), "body")
})

test_that("project-scoped getters validate their ids", {
  expect_error(diario_get_project_details(""), "project_id")
  expect_error(diario_get_task_list(42), "project_id")
  expect_error(diario_get_task_details("p", ""), "task_id")
  expect_error(diario_get_report_details("p", 7), "report_id")
})

test_that("diario_get_reports() validates limit and order", {
  expect_error(diario_get_reports("p", limit = 0), "limit")
  expect_error(diario_get_reports("p", limit = -1), "limit")
  expect_error(diario_get_reports("p", limit = "ten"), "limit")
  expect_error(diario_get_reports("p", order = "ascending"), "order")
  expect_error(diario_get_reports("p", order = "ASC"), "order")
})
