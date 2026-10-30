class EnableExtensions < ActiveRecord::Migration[8.1]
  def change
    enable_extension "postgis"
    enable_extension "citext"
  end
end
