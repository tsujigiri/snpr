class Comment < ActiveRecord::Base
  belongs_to :commentable, polymorphic: true
  belongs_to :author, class_name: 'User', foreign_key: :user_id
  belongs_to :parent, class_name: 'Comment', foreign_key: :comment_id
  has_many :children, class_name: 'Comment', foreign_key: :comment_id
end
