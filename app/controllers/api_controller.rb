class ApiController < ApplicationController
  protect_from_forgery with: :null_session, if: ->{request.format.json?}
  before_action :authorized

  private
    def encode_token(payload, secret)
      JWT.encode(payload, secret)
    end

    def decoded_token
      decode(auth_token, Settings::TOKEN_SECRET)
    end
    
    def decoded_refresh_token(token)
      decode(token, Settings::REFRESH_SECRET)
    end

    def auth_header
      request.headers['Authorization']
    end

    def auth_token
      token = auth_header.gsub('Bearer ','')
    end

    def decode(token, secret)
      return nil if token.blank?

      JWT.decode(token, secret, true, algorithm: 'HS256')[0]
    rescue JWT::DecodeError => e
      nil
    end

    def auth_user
      return @user unless @user.blank?
      if decoded_token
        user_id = decoded_token['id']
        @user = User.find_by(id: user_id)
        @user
      end
    end

    def logged_in?
      !!auth_user
    end

    def authorized
      render json: { message: 'Please log in' }, status: :unauthorized unless logged_in?
    end

end
