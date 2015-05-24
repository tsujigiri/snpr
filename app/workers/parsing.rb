class Parsing
  include Sidekiq::Worker
  sidekiq_options queue: :user_snps, retry: 5, unique: true

  attr_reader :genotype, :genotype_node, :user_snps, :snps, :stats, :start_time

  def perform(genotype_id)
    @stats = {}
    @start_time = Time.current
    @genotype = Genotype.find(genotype_id)
    logger.info("Started parsing #{genotype.filetype} genotype with id #{genotype_id}")
    stats[:filetype] = genotype.filetype
    stats[:genotype_id] = genotype.id
    @temp_table_name = "user_snps_temp_#{genotype.id}"
    @tempfile = Tempfile.new("snpr_genotype_#{genotype.id}_")

    send_logged(:normalize_csv)
    Neo4j::Transaction.run do
      send_logged(:insert_genotype)
      send_logged(:insert_snps)
      send_logged(:insert_user_snps)
    end
    send_logged(:notify_user)

    stats[:duration] = "#{(Time.current - start_time).round(3)}s"
    logger.info("Finished parsing: #{stats.to_a.map { |s| s.join('=') }.join(', ')}")
  rescue => e
    logger.error("Failed with #{e.class}: #{e.message}")
    fail
  end

  def normalize_csv
    rows = File.readlines(genotype.genotype.path)
      .reject { |line| line.start_with?('#') } # Skip comments
    stats[:rows_without_comments] = rows.length
    user_snps = send(:"parse_#{genotype.filetype.gsub('-', '_').downcase}", rows)
    known_chromosomes = ['MT', 'X', 'Y', (1..22).map(&:to_s)].flatten
    user_snps.select! do |row|
      row[:snp_name].present? &&
      known_chromosomes.include?(row[:chromosome]) &&
      row[:position].to_i >= 1 && row[:position].to_i <= 249_250_621 &&
      row[:local_genotype].is_a?(String) && (1..2).include?(row[:local_genotype].length)
    end
    stats[:rows_after_parsing] = user_snps.count
    @user_snps = user_snps.lazy
  end

  def insert_genotype
    Graph::Genotype.find_by(genotype_id: genotype.id).try(:destroy)
    @genotype_node = Graph::Genotype.create!(genotype_id: genotype.id)
  end

  def insert_snps
    @snps = user_snps.map do |user_snp|
      Graph::Snp.find_or_create_by!(name: user_snp[:snp_name])
    end
  end

  def insert_user_snps
    snps.each do |snp|
      genotype_node.snps << snp
    end
    genotype_node.save!
  end

  def parse_23andme(rows)
    rows.map do |row|
      fields = row.strip.split("\t")
      {
        snp_name: fields[0],
        chromosome: fields[1],
        position: fields[2],
        local_genotype: fields[3].to_s.rstrip,
      }
    end
  end

  def parse_23andme_exome_vcf(rows)
    # Rules:
    # Skip lines with IndelType in them
    # Skip lines were SNP name is '.', these are non-standard SNPs
    rows.map do |row|
      next if row.include? 'IndelType'
      fields = row.strip.split("\t")
      next if fields[2] == '.'
      major_allele = fields[3] # C
      minor_allele = fields[4] # A
      trans_dict = {"0" => major_allele, "1" => minor_allele}
      names = fields[-1].split(":")[0].split("/") # ["0", "1"], meaning A/C
      alleles = names.map{ |a| trans_dict[a]}.sort.join # becomes AC
      {
        snp_name: fields[2],
        chromosome: fields[0],
        position: fields[1],
        local_genotype: alleles,
      }
    end.compact # because the above next introduces nil.
    # Slower alternative is to use reject first, but then we'll iterate > 2 times
  end

  def parse_decodeme(rows)
    rows.shift if rows.first.start_with?('Name')
    rows.map do |row|
      fields = row.strip.split(',')
      {
        snp_name: fields[0],
        chromosome: fields[2],
        position: fields[3],
        local_genotype: fields[5],
      }
    end
  end

  def parse_ancestry(rows)
    rows.shift if rows.first.start_with?('rsid')
    rows.map do |row|
      fields = row.strip.split("\t")
      {
        snp_name: fields[0],
        chromosome: fields[1],
        position: fields[2],
        local_genotype: "#{fields[3]}#{fields[4]}",
      }
    end
  end

  def parse_ftdna_illumina(rows)
    rows.shift if rows.first.start_with?('RSID')
    rows.map do |row|
      fields = row.strip.split(',')
      {
        snp_name: fields[0].to_s.gsub('"', ''),
        chromosome: fields[1].to_s.gsub('"', ''),
        position: fields[2].to_s.gsub('"', ''),
        local_genotype: fields[3].to_s.gsub('"', ''),
      }
    end
  end

  def parse_iyg(rows)
    db_snp_names = {
      "MT-T3027C" => "rs199838004", "MT-T4336C" => "rs41456348",
      "MT-G4580A" => "rs28357975", "MT-T5004C" => "rs41419549",
      "MT-C5178a" => "rs28357984", "MT-A5390G" => "rs41333444",
      "MT-C6371T" => "rs41366755", "MT-G8697A" => "rs28358886",
      "MT-G9477A" => "rs2853825", "MT-G10310A" => "rs41467651",
      "MT-A10550G" => "rs28358280", "MT-C10873T" => "rs2857284",
      "MT-C11332T" => "rs55714831", "MT-A11947G" => "rs28359168",
      "MT-A12308G" => "rs2853498", "MT-A12612G" => "rs28359172",
      "MT-T14318C" => "rs28357675", "MT-T14766C" => "rs3135031",
      "MT-T14783C" => "rs28357680"
    }
    rows.map do |row|
      snp_name, local_genotype = row.split("\t")
      if snp_name.start_with?('MT')
        position = snp_name[/[0-9]+/]
        chromosome = 'MT'
      else
        position = chromosome = '1'
      end
      {
        snp_name: db_snp_names.fetch(snp_name, snp_name),
        chromosome: chromosome,
        position: position,
        local_genotype: local_genotype.strip,
      }
    end
  end

  def notify_user
    UserMailer.finished_parsing(genotype.id, stats).deliver_later
  end

  def execute(sql)
    Genotype.connection.execute(sql)
  end

  def logger
    return @logger if @logger
    @logger = Logger.new(Rails.root.join("log/parsing_#{Rails.env}.log"))
    @logger.formatter = Logger::Formatter.new
    @logger
  end

  def send_logged(method)
    start_time = Time.now
    ret = send(method)
    took = Time.now - start_time
    logger.info("calling of method `#{method}` took #{took} s")
    ret
  end
end

