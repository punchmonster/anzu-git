return function(self)

  -- Page title
  self.page_title = "error"
  self.header_vis = false

  -- storing error types and pushing them to view
  local t = {
    ["err_time_limit"]        = { "You\'re posting too fast" , "bar" },
    ["err_thread_max_length"] = { "Thread reply limit reached" , "bar" },
    ["err_invalid_file"]      = { "File isn\'t valid" , "bar" },
    ["err_character_limit"]   = { "Your post body or title is too long" , "bar" },
    ["err_not_allowed"]       = { "Not allowed" , "bar" }
  }

  self.error_result = t[self.params.errorCode]

  return { render = "error" }
end
