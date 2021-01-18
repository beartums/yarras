Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  namespace :api do
    namespace :v1 do
      #Auths
      post "/login", to: "auth#login", as: "login"
      post "/refresh_mah_token", to: "auth#refresh_mah_token", as: "refresh"
      post "/confirm_email", to: "auth#confirm_email", as: "confirm_email"
      post "/reset_password", to: "auth#reset_password", as: "reset_password"
      get "/request_password_reset", to: "auth#request_password_reset", as: "request_password_reset"
      get "/is_authenticated", to: "auth#is_authenticated", as: "is_authenticated"

    end
  end
end
