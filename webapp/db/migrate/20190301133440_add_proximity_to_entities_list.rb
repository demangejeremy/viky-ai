class AddProximityToEntitiesList < ActiveRecord::Migration[5.1]
  def change
    add_column :entities_lists, :proximity, :integer, default: EntitiesList.proximities['glued']
  end
end
