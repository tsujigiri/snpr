module Graph
  class Snp
    include Neo4j::ActiveNode

    property :name, type: String, constraint: :unique

    has_many :in, :genotypes, origin: :snps, model_class: Graph::Genotype
  end
end
