local csrf        = require "lapis.csrf"
local User        = require "models.user"


return {
  before = function(self)

    -- Page title
    self.page_title = "search"
  end,

  GET = function(self)

    -- generate token for page verification
    self.csrf_token = csrf.generate_token(self)
    self.submit_url = self:url_for("search")

    return { render = "search" }
  end,

  POST = function(self)

    return 0
  end
}
