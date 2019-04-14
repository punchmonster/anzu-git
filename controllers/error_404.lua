return function(self)

  -- Page title
  self.page_title = "404 - we messed up"

  return { render = "error_404", status = "404" }
end
