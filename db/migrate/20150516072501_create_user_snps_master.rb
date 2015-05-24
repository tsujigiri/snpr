class CreateUserSnpsMaster < ActiveRecord::Migration
  def up
    remove_index :snps, :name
    add_index :snps, :name, unique: true

    connection.execute(<<-SQL)
      CREATE TABLE user_snps_master (
        snp_name varchar(32) REFERENCES snps (name) NOT NULL,
        genotype_id integer REFERENCES genotypes NOT NULL,
        local_genotype char(2) NOT NULL,
        PRIMARY KEY (snp_name, genotype_id)
      )
    SQL
  end

  def down
    connection.execute('DROP TABLE user_snps_master CASCADE')
  end
end
