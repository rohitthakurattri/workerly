class CreateGeo < ActiveRecord::Migration[8.1]
  def change
    create_table :countries do |t|
      t.string :iso2, null: false, limit: 2
      t.string :name, null: false
      t.string :currency_code, null: false, limit: 3
      t.string :phone_prefix, null: false
      t.timestamps
    end
    add_index :countries, :iso2, unique: true

    create_table :states do |t|
      t.references :country, null: false, foreign_key: true, index: false
      t.string :code, null: false            # ISO 3166-2 suffix, e.g. PB, CH
      t.string :name, null: false
      t.string :kind, null: false, default: "state"
      t.timestamps
    end
    add_index :states, %i[country_id code], unique: true
    add_check_constraint :states, "kind IN ('state','union_territory')", name: "states_kind_check"

    create_table :cities do |t|
      t.references :state, null: false, foreign_key: true
      t.string :slug, null: false
      t.jsonb :name_i18n, null: false, default: {}
      t.string :currency_code, null: false, limit: 3
      t.string :time_zone, null: false
      t.st_point :center, geographic: true, srid: 4326, null: false
      t.integer :service_radius_m, null: false, default: 30_000
      t.boolean :launched, null: false, default: false
      t.timestamps
    end
    add_index :cities, :slug, unique: true
    add_index :cities, :center, using: :gist
    add_check_constraint :cities, "service_radius_m BETWEEN 1000 AND 100000", name: "cities_service_radius_check"
  end
end
