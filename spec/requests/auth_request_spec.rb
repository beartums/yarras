require 'rails_helper'
require 'settings'
include ActiveSupport::Testing::TimeHelpers

RSpec.describe "Auth", type: :request do

  context "#login" do
    let(:user) {User.create( username: 'username', password: password, email: 'username@example.com')}
    let(:password) {'password'}

    it "logs in using username" do
      post "/api/v1/login", :params => { username: user.username, password: password }
      expect(response).to have_http_status(200)
      expect(JSON.parse(response.body)).to include("username","token", "refresh_token")
    end

    it "logs in using email" do
      post "/api/v1/login", :params => { username: user.email, password: password }
      expect(response).to have_http_status(200)
      expect(JSON.parse(response.body)).to include("username","token", "refresh_token")
    end

    it "logs in using email with caps" do
      post "/api/v1/login", :params => { username: user.email.upcase, password: password }
      expect(response).to have_http_status(200)
      expect(JSON.parse(response.body)).to include("username","token", "refresh_token")
    end

    it "rejects invalid login" do
      post "/api/v1/login", :params => { username: user.username, password: "wrongpa sswrord" }
      expect(response).to have_http_status(:unauthorized)
      json = JSON.parse(response.body)
      expect(json).to include("error", "messages")
    end

    it "accepts a valid token" do
      post '/api/v1/login', 
            :params => { username: user.username, password: password}
      token = JSON.parse(response.body)['token']
      get "/api/v1/is_authenticated", :params => { first_name: 'boogerpup' }, 
                                      :headers => { "Authorization": "Bearer #{token}" }
      expect(response).to have_http_status(:ok)
    end

    it "rejects an expired token" do
      travel (-1 * ( 60.minutes + Settings::TOKEN_TIMEOUT) )
      post '/api/v1/login', 
            :params => { username: user.username, password: password}
      token = JSON.parse(response.body)['token']
      
      travel_back
      get "/api/v1/is_authenticated", :params => { first_name: 'boogerpup' }, 
                                      :headers => { "Authorization": "Bearer #{token}" }
      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)['message']).to eq("Please log in")
    end

  end

  context "#confirm_email" do
  let(:user) { User.find_by(username: 'test') }

    before do
      allow(VerificationMailer).to receive_message_chain(:confirmation_email, :deliver_now)
    end

    it "requires valid user id and correct change code" do
      code = user.request_email_confirmation
      get '/api/v1/confirm_email', :params => { uid: user.id, code: code }
      expect(response.status).to eq(200)
      expect(response.body).to include('token')
      user.reload
      expect(user.email_confirmation_digest).to eq(nil)
      expect(user.email_confirmed_at).to be_within(10.seconds).of(Time.now)
    end

    it "rejects an expired change code" do
      code = user.request_email_confirmation
      user.email_confirmation_requested_at = Time.now - 5.hours
      user.save
      get '/api/v1/confirm_email', :params => { uid: user.id, code: code }
      expect(response.status).to eq(401)
      user.reload
      expect(user.email_confirmation_digest).not_to eq(nil)
      expect(user.email_confirmed_at).to be(nil)
    end

  end

  context "token/refeesh_token workflow" do
    let(:user) {User.create( username: 'username', password: password, email: 'username@example.com')}
    let(:password) {'password'}

    it "expires token and uses refresh token to re-authorize" do
      post '/api/v1/login', :params => { username: user.username, password: password}
      token = JSON.parse(response.body)['token']
      refresh_token = JSON.parse(response.body)['refresh_token']
      get '/api/v1/is_authenticated', :headers => { "Authorization": "Bearer #{token}" }
      expect(response).to have_http_status(:ok)

      travel Settings::TOKEN_TIMEOUT + 1.hour
      get "/api/v1/is_authenticated", :headers => { "Authorization": "Bearer #{token}" }
      expect(response).to have_http_status(:unauthorized)

      post "/api/v1/refresh_mah_token", :params => { refresh_token: refresh_token }
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to include('token', 'refresh_token')

      token = JSON.parse(response.body)['token']
      get "/api/v1/is_authenticated", :headers => { "Authorization": "Bearer #{token}" }
      expect(response).to have_http_status(:ok)
    end
  end

  context "#password_reset" do

    context "when receiving a reset request" do
      let(:user) { User.find_by(username: 'test') }

      before do
        ActionMailer::Base.deliveries = []
      end

      it "sends a password reset email for valid username" do
        post '/api/v1/request_password_reset', :params => { username: 'test' }
        expect(user.reset_password_digest).not_to eq(nil)
        expect(ActionMailer::Base.deliveries.size).to eq(1)
        expect(response.status).to eq(200)
      end

      it "sends a password reset email for valid email" do
        post '/api/v1/request_password_reset', :params => { username: 'test@example.com' }
        expect(user.reset_password_digest).not_to eq(nil)
        expect(ActionMailer::Base.deliveries.size).to eq(1)
        expect(response.status).to eq(200)
      end

      it "ignores and invalid username/password, but sends and OK response" do
        post '/api/v1/request_password_reset', :params => { username: 'notavalidname' }
        expect(user.reset_password_digest).to eq(nil)
        expect(ActionMailer::Base.deliveries.size).to eq(0)
        expect(response.status).to eq(200)
      end
    end

    context "when posting a password reset" do
      let(:user) { User.find_by(username: 'test') }

      before do
        allow(VerificationMailer).to receive_message_chain(:password_reset_email, :deliver_now)
      end

      it "changes the password if the request is legitimate" do
        code = user.request_password_reset
        get '/api/v1/reset_password', :params => { code: code, username: 'test', password: 'new_password' }
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)).to include("username","token", "refresh_token")
        user.reload
        expect(user.reset_password_digest).to be(nil)
        expect(user.reset_password_created_at).to be(nil)
        expect(user.authenticate('new_password')).to be_truthy
      end

      it "rejects the changes if the code is incorrect" do
        code = user.request_password_reset
        get '/api/v1/reset_password', :params => { code: '9834579789', username: 'test', password: 'new_password' }
        expect(response.status).to eq(401)
        user.reload
        expect(user.reset_password_digest).not_to be(nil)
        expect(user.reset_password_created_at).not_to be(nil)
        expect(user.authenticate('test')).to be_truthy
      end

    end
  end

end
