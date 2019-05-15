return function(self)
  if not self.session.theme then
    self.session.theme = "dark"
  end

  self.theme = self.session.theme
end
