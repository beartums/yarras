class Settings
  REFRESH_TOKEN_TIMEOUT = 24.hours
  TOKEN_TIMEOUT = 1.hour

  TOKEN_SECRET = ENV['TOKEN_SECRET']
  REFRESH_SECRET = ENV['REFRESH_SECRET']
  ISSUER = 'yarras.apps.griffithnet.com'
end