FactoryGirl.define do
  factory :comment do
    association :author, factory: :user
    association :commentable, factory: :snp
    text 'Such comment! Very insight! Wow!'
  end
end
