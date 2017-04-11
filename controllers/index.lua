local Feeds       = require "models.feeds"

return function(self)

  -- Page title
  self.page_title = "home"

  -- get all feed info
  self.nav_data = Feeds:get_all()

  return { render = "index" }
end
