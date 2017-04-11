local Posts       = require "models.posts"
local Feeds       = require "models.feeds"

return {

  before = function(self)
    -- get feeds for navigation
    self.nav_data = Feeds:get_all()
    self.page_type = "catalog"
  end,

  GET = function(self)

    -- pass own page url
    self.submit_url = self:url_for("catalog")

    -- retrieve feed data from database
    local feed_info = Feeds:get_info(self.params.feedName)

    self.page_title = feed_info.feedName .. " - catalog"
    self.feed_desc  = feed_info.feedDesc

    -- retrieve thread data from database
    self.thread_data = Posts:get_threads(feed_info.feedName)

    -- pass current UNIX timestamp to view
    self.current_time = ngx.time()

    return { render = "catalog" }
  end,

  POST = function(self)

  end
}
