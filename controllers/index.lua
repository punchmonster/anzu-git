return function(self)

  -- Page title
  self.page_title = "home"

  -- get all feed info
  self.submit_url = self:url_for("index")

  return { render = "index" }
end
