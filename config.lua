local config = require("lapis.config")

config("development", {
  site_name    = "anzu development",
  port         = 8080,
  secret       = "change_me",
  mysql        = {
    host         = "127.0.0.1",
    user         = "root",
    password     = "change_me",
    database     = "anzu_test"
  }
})

config("production", {
	code_cache = "on",
	site_name  = "anzu production",
	port       = 80,
  secret       = "change_me",
  mysql        = {
    host         = "127.0.0.1",
    user         = "root",
    password     = "change_me",
    database     = "anzu_test"
  }
})
