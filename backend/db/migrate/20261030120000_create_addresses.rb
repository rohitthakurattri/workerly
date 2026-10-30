class CreateAddresses < ActiveRecord::Migration[8.1]
  def change
    create_table :addresses do |t|
      t.uuid :public_id, null: false
      t.references :user, null: false, foreign_key: true, index: false
      t.references :city, null: false, foreign_key: true   # derived from the pin, always a launched city
      t.string :label                                        # Home, Office, Parents
      t.string :line1, null: false                           # house / flat number and street
      t.string :line2
      t.string :landmark
      t.string :locality, null: false                        # sector or area: the only part workers see before booking
      t.string :pincode, null: false
      t.st_point :location, geographic: true, srid: 4326, null: false
      t.boolean :is_default, null: false, default: false
      t.datetime :deleted_at                                 # soft delete: submitted requests keep pointing here
      t.timestamps
    end
    add_index :addresses, :public_id, unique: true
    add_index :addresses, %i[user_id created_at], where: "deleted_at IS NULL"
    add_index :addresses, :user_id, unique: true, where: "is_default AND deleted_at IS NULL",
      name: "index_addresses_one_default_per_user"
    add_index :addresses, :location, using: :gist
    add_check_constraint :addresses, "pincode ~ '^[1-9][0-9]{5}$'", name: "addresses_pincode_check"
  end
end
