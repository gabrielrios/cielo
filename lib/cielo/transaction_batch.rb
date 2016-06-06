module Cielo
  class TransactionBatch
    BOUNDARY = "AaB03x"

    def initialize(batch_number, operation, transactions,
                   affiliation_number = Cielo.numero_afiliacao,
                   access_key = Cielo.chave_acesso)
      @batch_number = batch_number
      @operation = operation
      @connection = Cielo::Connection.new(affiliation_number, access_key)
      @connection.path = "/lote/ecommwsecLoteDownload.do"
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
      post_body << "--#{BOUNDARY}\r\n"
      post_body << "Content-Disposition: form-data; name=\"mensagem\"; filename=\"#{filename}\"\r\n"
      post_body << "\r\n"
      post_body << xml
      post_body << "\r\n--#{BOUNDARY}--\r\n"

      http = Net::HTTP.new(@connection.environment::BASE_URL, 443)
      http.ssl_version = :TLSv1 if @http.respond_to? :ssl_version
      http.use_ssl = true
      request = Net::HTTP::Post.new("/lote/ecommwsecLoteUpload.do")
      request.body = post_body.join
      request["Content-Type"] = "multipart/form-data, boundary=#{BOUNDARY}"

      connection.parse_response(http.request(request))
    end

    def filename
      "ECOMM_#{@connection.numero_afiliacao}_#{@operation.to_s.rjust(2, '0')}_#{date}_#{batch_number}.xml"
    end

    def date
      Date.today.strftime('%Y%m%d')
    end

    def batch_number
      @batch_number.to_s.rjust(10, '0')
    end


    def build_xml
      connection.xml_builder('requisicao-lote', {}) do |xml, target|
        if target == :after
          xml.tag!('numero-lote', @batch_number)
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
          xml.tag!('numero-lote', @batch_number)
        end
      end
    end
  end
end
