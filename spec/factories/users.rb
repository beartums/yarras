FactoryBot.define do
  factory :user do
    username { "username" }
    password { "password" }
    email { "username@example.com" }
    password_confirmation { nil }
  end
end