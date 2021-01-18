class CreateUsers < ActiveRecord::Migration[6.1]
  def change
    create_table :users do |t|
      t.string :email
      t.string :username
      t.string :first_name
      t.string :last_name
      t.boolean :admin
      t.string :password_digest
      t.string :reset_password_digest
      t.string :email_confirmation_digest
      t.datetime :reset_password_created_at
      t.datetime :email_confirmation_requested_at
      t.datetime :email_confirmed_at

      t.timestamps
    end
  end
end
