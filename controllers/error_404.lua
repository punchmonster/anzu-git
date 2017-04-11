local Feeds       = require "models.feeds"

return function(self)

  -- Page title
  self.page_title = "404 - we messed up"

  -- get all feed info
  self.nav_data = Feeds:get_all()

  return { render = "error_404", status = "404" }
end
