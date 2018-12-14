# The test parser regards any word starting with an upper-case letter as a pre-existing term
require 'activefacts/cql/parser/Language/English'
class TestParser < ActiveFacts::CQL::Parser
  include ActiveFacts::CQL::English

  # Capitalised words that are otherwise undefined are treated as terms:
  def system_term(t)
    (first = t[0,1] and first.upcase == first) ? {t=>t} : false
  end
end
