local Feeds       = require "models.feeds"

return {
  before = function(self)
    -- get feeds for navigation
    self.nav_data = Feeds:get_all()
    self.header_vis = false
  end,

  GET = function(self)

    -- Page title
    self.page_title = "login"

    return { render = "login" }
  end,

  POST = function(self)

  end
}
