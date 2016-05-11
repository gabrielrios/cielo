module Cielo
  class TransactionBatch
    def initialize(transactions)
      @connection = Cielo::Connection.new
      @transactions = transactions
    end

    attr_reader :connection, :transactions

    def xml
      build_xml.target!
    end

    def build_xml
      connection.xml_builder('requisicao-consulta') do |xml, target|
        if target == :after
          transactions.each do |transaction|
            xml << transaction.xml
          end
        end
      end
    end
  end
end
