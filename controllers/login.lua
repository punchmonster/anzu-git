local Feeds       = require "models.feeds"

return function(self)

  -- Page title
  self.page_title = "login"

  -- get all feed info
  self.header_vis = false
  self.nav_data = Feeds:get_all()

  return { render = "login" }
end
