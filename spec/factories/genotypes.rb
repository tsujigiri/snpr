# frozen_string_literal: true
FactoryGirl.define do
  factory :genotype do
    genotype_file_name 'foo.txt'
    user
  end
end
