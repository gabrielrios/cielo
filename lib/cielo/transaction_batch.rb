module Cielo
  class TransactionBatch
    def initialize(batch_number, operation, transactions)
      @batch_number = batch_number
      @operation = operation
      @connection = Cielo::Connection.new
      @transactions = transactions
    end

    attr_reader :connection, :transactions, :batch_number, :operation

    def xml
      build_xml.target!
    end

    def create!
      @connection.make_request!(build_xml)
    end

    def build_xml
      connection.xml_builder('requisicao-lote') do |xml, target|
        xml.tag!('numero-lote', batch_number)
        xml.tag!('tipo-operacao', operation)
        xml.tag!('lista-requisicoes') do
          transactions.each do |transaction|
            xml << transaction.xml
          end
        end
      end
    end
  end
end
