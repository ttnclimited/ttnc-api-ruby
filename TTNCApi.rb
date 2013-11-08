require 'rexml/document'
require 'digest/sha1'
require 'net/http'
require 'uri'
require 'securerandom'
include REXML
class TTNCApi
  attr_reader :element
  attr_reader :username
  attr_reader :password
  attr_reader :vkey
  attr_accessor :requests
  attr_accessor :response
  def initialize(username=false,password=false,vkey=false)
    # Instance variable
    @username = username
    @password = password
    @vkey     = vkey
    @response = false
    @requests = {}
    @element  = REXML::Document.new 
    @noveroresponse = element.add_element 'NoveroRequest'
    if(username!=false && password!=false)
      sessionrequest()
    end
  end
  
  def usesession(sessionId)
    child = REXML::Document.new 
    child_tmp = child.add_element("SessionId")
    child_tmp.text = sessionId
    @noveroresponse.add_element child
  end
  
  def sessionrequest()
    request = newrequest('Auth', 'SessionLogin', 'SessionRequest')
    request.setdata('Username', @username)
    request.setdata('Password', @password)
    if(@vkey!=false)
      request.setdata('VKey',@vkey)
    end
  end

  def newrequest(target,name,id = false)
    request = TTNCRequest.new(self,target,name,id)
    requests[request.requestid]=request
    return @requests[request.requestid]
  end
  
  def getresponsefromid(id)
    @response.get().elements['NoveroResponse'].elements.each do |value|
      if(value.attributes['RequestId'] == id)
        return requesttoarray(value)
      end
    end
  end
  
  def requesttoarray(xml)
    all_infos={}
    if(xml.attributes.length>0)
      all_infos['@attributes']=xml.attributes
    end
    xml.elements.each do |value|
      if(value.children.length>1)
        all_infos[value.name]=requesttoarray(value)
      else
        all_infos[value.name]=value.text
      end
    end
    return all_infos
  end
  
  def makerequest()
    @requests.each do |key,value|
      @noveroresponse.add_element(value.element)
    end
    formatter = REXML::Formatters::Pretty.new(2)
    formatter.compact = true
    uri = URI.parse("http://xml.ttnc.co.uk/api/")
    http = Net::HTTP.new(uri.host, uri.port)
    req = Net::HTTP::Post.new(uri.path, {'Content-Type' =>'text/xml\r\n'})
    xml_request_content = ''
    formatter.write(@element, xml_request_content)
    puts xml_request_content
    req.body = xml_request_content
    res = http.request(req)
    puts res.body
    @response=TTNCResponse.new(res.body)
  end
  
end

class TTNCRequest
  attr_accessor :requestid
  attr_reader :element
  def initialize(api,target,name,id)
    # Instance variable
    @api = api
    @requestid=(id!=false)?id:generaterequestid()
    @element = REXML::Document.new
    @request = @element.add_element 'Request'
    @request.attributes['target']=target
    @request.attributes['name']=name
    @request.attributes['id']=@requestid
  end
  def generaterequestid()
    return Digest::SHA1.hexdigest SecureRandom.hex(32)
  end
  def setdata(key,value)
    child = REXML::Document.new 
    child_tmp= child.add_element(key)
    child_tmp.text=value
    @request.add_element child
  end
  def get()
    return @request
  end
  def getid()
    return @requestid
  end
    
  def getresponse()
    if(!@api.response)
      return false
    else
      return @api.getresponsefromid(@requestid)
    end
  end

end

class TTNCResponse
  #variable
  def initialize(response)
    # Instance variable
    if(response.is_a? String)
      @xml=REXML::Document.new(response)
    elsif(response.is_a? REXML::Document)
      @xml=response
    end
    def get()
      return @xml
    end
  end
end
