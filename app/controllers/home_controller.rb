require 'net/http'
require 'uri'
require 'json'

class HomeController < ApplicationController
  
  def index
    #@users = User.all.map{|user| [user.username, user.id] } 
  end

  def search
    query_string = params[:query_string]#.replace(' ', '_')
    query = <<-QUERY
        SELECT DISTINCT ?uri, ?page WHERE {
          ?uri rdf:type <http://dbpedia.org/ontology/Sport>.
          ?uri rdfs:label ?label.
          ?uri foaf:page ?page
          FILTER(regex(fn:lower-case(?label), fn:lower-case("#{query_string}")))
        }
      QUERY
    params = {:query => query, 
             :format => "application/sparql-results+json",
             'default-graph-uri' => "http://dbpedia.org"}

    postData = Net::HTTP.post_form(URI.parse('http://dbpedia.org/sparql'), params)
    
    begin
      @results = JSON.parse(postData.body)["results"]["bindings"]
    rescue
      @results = []
    end
    
    respond_to do |format|
      format.html{ @results }
      format.json{ render :json => @results.to_json }
    end
  end

end

# select distinct ?uri, ?sc, ?rank where 
#  { 
#    { 
#      {
#        select ?uri, ( ?sc * 3e-1 ) as ?sc, ?o1, ( sql:rnk_scale ( <LONG::IRI_RANK> ( ?uri ) ) ) as ?rank where 
#        { 
#          ?uri ?s1textp ?o1 .
#          ?o1 bif:contains '"#{params[:query_string]}"' option ( score ?sc ) .
# 
#        }
#       order by desc ( ?sc * 3e-1 + sql:rnk_scale ( <LONG::IRI_RANK> ( ?uri ) ) ) limit 20 offset 0 
#      }
#     }
#   }

# SELECT ?x ?label WHERE {
#   ?x rdfs:label ?label
#   FILTER(regex(?label,"^foot"))
# }