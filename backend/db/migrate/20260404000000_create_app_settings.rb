class CreateAppSettings < ActiveRecord::Migration[7.0]
  def change
    create_table :app_settings do |t|
      t.string :key, null: false
      t.text :value
      t.text :description

      t.timestamps
    end

    add_index :app_settings, :key, unique: true
  end
end
