class CreateComments < ActiveRecord::Migration
  def change
    create_table :comments do |t|
      t.text 'text'
      t.belongs_to :user, null: false
      t.belongs_to :commentable, polymorphic: true, null: false
      t.belongs_to :comment
      t.timestamps null: false
    end
  end
end
