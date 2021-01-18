module Api
  module V1
    class AuthController < ApiController
      before_action :authorized, only: [:is_authenticated]

      def login
        user = find_user

        if user && user.authenticate(params[:password])
          render json: return_payload(user), status: 200
        else
          render json: {error: "Invalid username or password", messages: user.errors.messages}, status: :unauthorized
        end
      end

      def confirm_email
        user = User.find(params[:uid])
        confirmation_code = params[:code]
        if user && user.confirm_email(confirmation_code)
          render json: return_payload(user, "Email confirmed!  You are logged in"), status: 200
        else
          render json: { error: "confirmation rejected" }, status: :unauthorized
        end
      end

      def request_password_reset
        user = find_user
        user.try(:request_password_reset)
        render json: { msg: "An email has been sent to the username or email that you submitted" }, status: 200
      end

      def reset_password
        user = find_user
        if user && user.reset_password(params[:code], params[:password], params[:password_confirmation])
          render json: return_payload(user, "Password reset!  You are logged in"), status: :ok
          # redirect_to '/login'
        else
          render json: { error: "new password rejected" }, status: :unauthorized
        end
      end

      def refresh_mah_token
        payload = decoded_refresh_token(params[:refresh_token])
        if payload
          user = User.find(payload['id'])
          render json: return_payload(user, "Token Refreshed"), status: :ok
        else
          render json: { error: "Rejected!" }, status: :unauthorized
        end
      end

      def is_authenticated
        render json: { message: 'Yep! You are logged in!'}, status: :ok if logged_in?
      end

      private

      def user_params
        params.permit(:username, :password, :email)
      end

      def find_user
        User.find_by(username: params[:username]) || User.find_by(email: params[:username].downcase)
      end

      def token_payload(user, refresh = false)
        iss = Settings::ISSUER
        exp = Time.now + (refresh ? Settings::REFRESH_TOKEN_TIMEOUT : Settings::TOKEN_TIMEOUT)
        { id: user.id, username: user.username, iss: iss, exp: (exp).to_i }
      end

      def token(user, refresh = false)
        secret = refresh ? Settings::REFRESH_SECRET : Settings::TOKEN_SECRET
        encode_token(token_payload(user, refresh), secret)
      end
      
      def return_payload(user, msg = 'You are logged in.')
        { msg: msg, username: user.username, token: token(user), refresh_token: token(user, true) }
      end

    end
  end
end
