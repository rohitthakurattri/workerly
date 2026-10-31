class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications do |t|
      t.uuid :public_id, null: false
      t.references :user, null: false, foreign_key: true, index: false
      t.string :kind, null: false                        # lead.new, request.matched, …
      t.string :title, null: false
      t.string :body
      t.string :url                                      # where the app opens it (path)
      t.jsonb :data, null: false, default: {}
      t.string :channels, array: true, null: false, default: []   # in_app, push, sms: where it was delivered
      t.datetime :read_at
      t.timestamps
    end
    add_index :notifications, :public_id, unique: true
    add_index :notifications, %i[user_id created_at]
    add_index :notifications, :user_id, where: "read_at IS NULL", name: "index_notifications_unread"

    create_table :device_subscriptions do |t|
      t.uuid :public_id, null: false
      t.references :user, null: false, foreign_key: true
      t.string :platform, null: false, default: "webpush"
      t.string :app, null: false                         # customer | worker
      t.text :endpoint, null: false
      t.string :p256dh, null: false
      t.string :auth, null: false
      t.string :user_agent
      t.datetime :last_seen_at
      t.datetime :failed_at
      t.timestamps
    end
    add_index :device_subscriptions, :public_id, unique: true
    add_index :device_subscriptions, :endpoint, unique: true
    add_check_constraint :device_subscriptions, "platform IN ('webpush')", name: "device_subscriptions_platform_check"
    add_check_constraint :device_subscriptions, "app IN ('customer','worker')", name: "device_subscriptions_app_check"
  end
end
