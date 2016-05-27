module Cielo
  class TransactionBatch
    BOUNDARY = "AaB03x"

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

    def receive!
      @connection.make_request!(return_xml)
    end

    def create!
      post_body = []
      post_body << "--#{BOUNDARY}rn"
      post_body << "Content-Disposition: form-data; name=\"mensagem\"; filename=\"#{filename}\"rn"
      post_body << "Content-Type: text/plainrn"
      post_body << "rn"
      post_body << xml
      post_body << "rn--#{BOUNDARY}--rn"

      http = Net::HTTP.new(@connection.environment::BASE_URL, 443)
      http.ssl_version = :TLSv1 if @http.respond_to? :ssl_version
      http.use_ssl = true
      request = Net::HTTP::Post.new("/lote/ecommwsecLoteUpload.do")
      request.body = post_body.join
      request["Content-Type"] = "multipart/form-data, boundary=#{BOUNDARY}"

      connection.parse_response(http.request(request))
    end

    def filename
      "ECOMM_#{Cielo.numero_afiliacao}_#{@operation}_#{date}_#{batch_number}.xml"
    end

    def date
      Date.today.strftime('%Y%m%d')
    end

    def batch_number
      @batch_number.to_s.rjust(10, '0')
    end


    def build_xml
      connection.xml_builder('requisicao-lote') do |xml, target|
        if target == :after
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

    def return_xml
      connection.xml_builder('requisicao-download-retorno-lote') do |xml,target|
        if target == :after
          xml.tag!('numero-lote', batch_number)
        end
      end
    end
  end
end
