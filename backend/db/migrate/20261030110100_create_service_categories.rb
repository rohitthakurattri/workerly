class CreateServiceCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :service_categories do |t|
      t.references :parent, foreign_key: { to_table: :service_categories }
      t.string :slug, null: false
      t.jsonb :name_i18n, null: false, default: {}
      t.jsonb :description_i18n, null: false, default: {}
      t.string :icon
      t.boolean :inspection_allowed, null: false, default: true
      t.boolean :active, null: false, default: true
      t.integer :sort, null: false, default: 0
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :service_categories, :slug, unique: true
    add_check_constraint :service_categories, "name_i18n ? 'en'", name: "service_categories_name_en_check"
    add_check_constraint :service_categories, "parent_id IS NULL OR parent_id <> id", name: "service_categories_parent_check"
  end
end
