# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20150916070052) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "hstore"
  enable_extension "pg_stat_statements"

  create_table "achievements", force: :cascade do |t|
    t.text     "award"
    t.string   "short_name", limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "active_admin_comments", force: :cascade do |t|
    t.string   "resource_id",   limit: 255, null: false
    t.string   "resource_type", limit: 255, null: false
    t.integer  "author_id"
    t.string   "author_type",   limit: 255
    t.text     "body"
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
    t.string   "namespace",     limit: 255
  end

  add_index "active_admin_comments", ["author_type", "author_id"], name: "index_active_admin_comments_on_author_type_and_author_id", using: :btree
  add_index "active_admin_comments", ["namespace"], name: "index_active_admin_comments_on_namespace", using: :btree
  add_index "active_admin_comments", ["resource_type", "resource_id"], name: "index_admin_notes_on_resource_type_and_resource_id", using: :btree

  create_table "admin_users", force: :cascade do |t|
    t.string   "email",                  limit: 255, default: "", null: false
    t.string   "encrypted_password",     limit: 255, default: "", null: false
    t.string   "reset_password_token",   limit: 255
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",                      default: 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip",     limit: 255
    t.string   "last_sign_in_ip",        limit: 255
    t.datetime "created_at",                                      null: false
    t.datetime "updated_at",                                      null: false
  end

  add_index "admin_users", ["email"], name: "index_admin_users_on_email", unique: true, using: :btree
  add_index "admin_users", ["reset_password_token"], name: "index_admin_users_on_reset_password_token", unique: true, using: :btree

  create_table "file_links", force: :cascade do |t|
    t.text     "description"
    t.text     "url"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "fitbit_activities", force: :cascade do |t|
    t.integer  "fitbit_profile_id"
    t.integer  "steps"
    t.integer  "floors"
    t.date     "date_logged"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "fitbit_bodies", force: :cascade do |t|
    t.integer  "fitbit_profile_id"
    t.date     "date_logged"
    t.float    "weight"
    t.float    "bmi"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "fitbit_profiles", force: :cascade do |t|
    t.string   "fitbit_user_id", limit: 255
    t.integer  "user_id"
    t.string   "request_token",  limit: 255
    t.string   "request_secret", limit: 255
    t.string   "access_token",   limit: 255
    t.string   "access_secret",  limit: 255
    t.string   "verifier",       limit: 255
    t.boolean  "body",                       default: true
    t.boolean  "activities",                 default: true
    t.boolean  "sleep",                      default: true
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "fitbit_sleeps", force: :cascade do |t|
    t.integer  "fitbit_profile_id"
    t.integer  "minutes_asleep"
    t.integer  "minutes_awake"
    t.integer  "number_awakenings"
    t.integer  "minutes_to_sleep"
    t.date     "date_logged"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "friendly_id_slugs", force: :cascade do |t|
    t.string   "slug",           limit: 255, null: false
    t.integer  "sluggable_id",               null: false
    t.string   "sluggable_type", limit: 40
    t.datetime "created_at"
  end

  add_index "friendly_id_slugs", ["slug", "sluggable_type"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type", unique: true, using: :btree
  add_index "friendly_id_slugs", ["sluggable_id"], name: "index_friendly_id_slugs_on_sluggable_id", using: :btree
  add_index "friendly_id_slugs", ["sluggable_type"], name: "index_friendly_id_slugs_on_sluggable_type", using: :btree

  create_table "genome_gov_papers", force: :cascade do |t|
    t.text     "first_author"
    t.text     "title"
    t.text     "pubmed_link"
    t.text     "pub_date"
    t.text     "journal"
    t.text     "trait"
    t.float    "pvalue"
    t.text     "pvalue_description"
    t.text     "confidence_interval"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "genotypes", force: :cascade do |t|
    t.string   "filetype",              limit: 255, default: "23andme"
    t.integer  "user_id",                                               null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "md5sum",                limit: 255
    t.string   "genotype_file_name",    limit: 255
    t.string   "genotype_content_type", limit: 255
    t.integer  "genotype_file_size"
    t.datetime "genotype_updated_at"
  end

  create_table "genotypes_by_snp", id: false, force: :cascade do |t|
    t.string "snp_name",               null: false
    t.hstore "genotypes", default: {}, null: false
  end

  add_index "genotypes_by_snp", ["snp_name"], name: "index_genotypes_by_snp_on_snp_name", unique: true, using: :btree

  create_table "homepages", force: :cascade do |t|
    t.text     "url"
    t.text     "description"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "user_id"
  end

  create_table "mendeley_papers", force: :cascade do |t|
    t.text     "first_author"
    t.text     "title"
    t.text     "mendeley_url"
    t.text     "doi"
    t.integer  "pub_year"
    t.string   "uuid",         limit: 255
    t.boolean  "open_access"
    t.integer  "reader"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "messages", force: :cascade do |t|
    t.text     "subject"
    t.integer  "user_id"
    t.text     "body"
    t.boolean  "sent"
    t.boolean  "user_has_seen"
    t.integer  "from_id"
    t.integer  "to_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "pgp_annotations", force: :cascade do |t|
    t.text     "gene"
    t.text     "qualified_impact"
    t.text     "inheritance"
    t.text     "summary"
    t.text     "trait"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "snp_id"
  end

  create_table "phenotype_comments", force: :cascade do |t|
    t.text     "comment_text"
    t.text     "subject"
    t.integer  "user_id"
    t.integer  "phenotype_id"
    t.integer  "reply_to_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "phenotype_sets", force: :cascade do |t|
    t.integer  "user_id"
    t.string   "title",       limit: 255
    t.text     "description"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "phenotype_sets_phenotypes", id: false, force: :cascade do |t|
    t.integer "phenotype_set_id"
    t.integer "phenotype_id"
  end

  create_table "phenotypes", force: :cascade do |t|
    t.string   "characteristic",   limit: 255
    t.text     "known_phenotypes"
    t.integer  "number_of_users",              default: 0
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "description"
  end

  create_table "picture_phenotype_comments", force: :cascade do |t|
    t.text     "comment_text"
    t.text     "subject"
    t.integer  "user_id"
    t.integer  "picture_phenotype_id"
    t.integer  "reply_to_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "picture_phenotypes", force: :cascade do |t|
    t.string   "characteristic",  limit: 255
    t.text     "description"
    t.integer  "number_of_users",             default: 0
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "plos_papers", force: :cascade do |t|
    t.text     "first_author"
    t.text     "title"
    t.text     "doi"
    t.datetime "pub_date"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "reader"
  end

  create_table "snp_comments", force: :cascade do |t|
    t.text     "comment_text"
    t.text     "subject"
    t.integer  "user_id"
    t.integer  "snp_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "reply_to_id"
  end

  create_table "snp_references", id: false, force: :cascade do |t|
    t.integer "snp_id",                 null: false
    t.integer "paper_id",               null: false
    t.string  "paper_type", limit: 255, null: false
  end

  add_index "snp_references", ["paper_id", "paper_type"], name: "index_snp_references_on_paper_id_and_paper_type", using: :btree
  add_index "snp_references", ["snp_id"], name: "index_snp_references_on_snp_id", using: :btree

  create_table "snpedia_papers", force: :cascade do |t|
    t.string   "url",        limit: 255
    t.text     "summary"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "revision",               default: 0
  end

  create_table "snps", force: :cascade do |t|
    t.string   "name",               limit: 255
    t.string   "position",           limit: 255
    t.string   "chromosome",         limit: 255
    t.string   "genotype_frequency", limit: 255, default: "--- {}\n"
    t.string   "allele_frequency",   limit: 255, default: "---\nA: 0\nT: 0\nG: 0\nC: 0\n"
    t.integer  "ranking",                        default: 0
    t.integer  "number_of_users",                default: 0
    t.datetime "mendeley_updated",               default: '2011-08-24 03:44:32'
    t.datetime "plos_updated",                   default: '2011-08-24 03:44:32'
    t.datetime "snpedia_updated",                default: '2011-08-24 03:44:32'
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "user_snps_count"
  end

  add_index "snps", ["chromosome", "position"], name: "index_snps_chromosome_position", using: :btree
  add_index "snps", ["id"], name: "index_snps_on_id", unique: true, using: :btree
  add_index "snps", ["name"], name: "index_snps_on_name", unique: true, using: :btree
  add_index "snps", ["position"], name: "snps_position_idx", using: :btree
  add_index "snps", ["ranking"], name: "index_snps_ranking", using: :btree

  create_table "snps_by_genotype", id: false, force: :cascade do |t|
    t.integer "genotype_id",              null: false
    t.hstore  "snps",        default: {}, null: false
  end

  add_index "snps_by_genotype", ["genotype_id"], name: "index_snps_by_genotype_on_genotype_id", unique: true, using: :btree

  create_table "user_achievements", force: :cascade do |t|
    t.integer  "user_id"
    t.integer  "achievement_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "user_phenotypes", force: :cascade do |t|
    t.integer  "user_id"
    t.integer  "phenotype_id"
    t.string   "variation",    limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "user_picture_phenotypes", force: :cascade do |t|
    t.integer  "user_id"
    t.integer  "picture_phenotype_id"
    t.string   "variation",                      limit: 255
    t.string   "phenotype_picture_file_name",    limit: 255
    t.string   "phenotype_picture_content_type", limit: 255
    t.integer  "phenotype_picture_file_size"
    t.datetime "phenotype_picture_updated_at"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "user_snps", id: false, force: :cascade do |t|
    t.string  "snp_name",       limit: 32
    t.integer "genotype_id"
    t.string  "local_genotype", limit: 2
  end

  add_index "user_snps", ["genotype_id"], name: "user_snps_new_genotype_id", using: :btree
  add_index "user_snps", ["snp_name"], name: "user_snps_new_snp_name", using: :btree

  create_table "user_snps_temp_2360", id: false, force: :cascade do |t|
    t.string "snp_name",       limit: 32
    t.string "chromosome",     limit: 32
    t.string "position",       limit: 32
    t.string "local_genotype", limit: 2
  end

  create_table "user_snps_temp_2362", id: false, force: :cascade do |t|
    t.string "snp_name",       limit: 32
    t.string "chromosome",     limit: 32
    t.string "position",       limit: 32
    t.string "local_genotype", limit: 2
  end

  create_table "user_snps_temp_2441", id: false, force: :cascade do |t|
    t.string "snp_name",       limit: 32
    t.string "chromosome",     limit: 32
    t.string "position",       limit: 32
    t.string "local_genotype", limit: 2
  end

  create_table "users", force: :cascade do |t|
    t.string   "name",                               limit: 255
    t.string   "email",                              limit: 255
    t.string   "password_salt",                      limit: 255
    t.string   "crypted_password",                   limit: 255
    t.string   "persistence_token",                  limit: 255
    t.string   "perishable_token",                   limit: 255
    t.boolean  "has_sequence",                                   default: false
    t.string   "sequence_link",                      limit: 255
    t.text     "description"
    t.boolean  "finished_snp_parsing",                           default: false
    t.integer  "phenotype_creation_counter",                     default: 0
    t.integer  "phenotype_additional_counter",                   default: 0
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "avatar_file_name",                   limit: 255
    t.string   "avatar_content_type",                limit: 255
    t.integer  "avatar_file_size"
    t.datetime "avatar_updated_at"
    t.boolean  "help_one",                                       default: false
    t.boolean  "help_two",                                       default: false
    t.boolean  "help_three",                                     default: false
    t.string   "sex",                                limit: 255, default: "rather not say"
    t.string   "yearofbirth",                        limit: 255, default: "rather not say"
    t.boolean  "message_on_message",                             default: true
    t.boolean  "message_on_snp_comment_reply",                   default: true
    t.boolean  "message_on_phenotype_comment_reply",             default: true
    t.boolean  "message_on_newsletter",                          default: true
    t.boolean  "message_on_new_phenotype",                       default: false
  end

  add_index "users", ["email"], name: "index_users_on_email", unique: true, using: :btree
  add_index "users", ["persistence_token"], name: "index_users_on_persistence_token", unique: true, using: :btree

  add_foreign_key "genotypes_by_snp", "snps", column: "snp_name", primary_key: "name"
  add_foreign_key "snps_by_genotype", "genotypes"
end
