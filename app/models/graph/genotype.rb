module Graph
  class Genotype
    include Neo4j::ActiveNode

    property :genotype_id, type: Integer, constraint: :unique

    has_many :out, :snps, type: :contains, model_class: Graph::Snp
  end
end
