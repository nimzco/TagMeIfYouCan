require 'rdf'
require 'rdf/raptor'  # for RDF/XML support
require 'rdf/ntriples'

include RDF
 
# begin 
#     graph = RDF::Graph.load("hello.nt", :format => :ntriples)
#     triple_writer = RDF::NTriples::Writer.new
#     
#     RDF::Writer.open("hello.nt") do |writer|
#         if !graph.has_triple?([RDF::Node.new(:hello), RDF::FOAF.like, 'lazdaazdl'])
#           graph << [:hello, RDF::FOAF.like, "lazdagal"]  
#         end
#         writer << graph
#     end
# rescue
#     puts "An error occured"    
# end


graph = RDF::Graph.load("people-film.nt")
query = RDF::Query.new do
#Meme réalisateur
#    pattern [:movie, RDF::URI.new("http://dbpedia.org/property/director"), RDF::URI.new('http://dbpedia.org/resource/Steven_Spielberg')]

#Meme Acteur
#    pattern [:movie, RDF::URI.new("http://dbpedia.org/ontology/starring"), RDF::URI.new('http://dbpedia.org/resource/Tom_Cruise')]


    #pattern [:movie, RDF::URI.new("http://purl.org/dc/terms/subject"), :cat]
                pattern [:pers, RDF::FOAF.like, :movie]
end

query.execute(graph).each do |solution|
  puts solution.pers + ' / ' + solution.movie
end