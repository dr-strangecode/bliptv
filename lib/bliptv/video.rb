require 'net/http'
require 'uri'
require 'open-uri'
require 'json'

module BlipTV

  BLIP_TV_ID_EXPR = /\d{3,12}/

  # Raised when pinging Blip.tv for video information results in an error
  class VideoResponseError < BlipTVError #:nodoc:
    def initialize(message)
      super message
    end
  end

  class VideoDeleteError < BlipTVError
    def intialize(message)
      super message
    end
  end

  # This class wraps Blip.tv's video's information.
  class Video

    attr_accessor :id,
                  :title,
                  :description,
                  :guid,
                  :deleted,
                  :views,
                  :tags,
                  :author,
                  :update_time,
                  :embed_url,
                  :embed_code,
                  :thumbnail_url,
                  :thumbnail120_url,
                  :cookie

    def initialize(json,options={}) #:nodoc:
      @cookie = options[:cookie] if options[:cookie]
      video_json = query_attributes(json)
      set_attributes_from_json(video_json)
    end

    def query_attributes(json)
      url = "#{json['url']}?skin=json&version=2"
      request = open(url,{"UserAgent" => "Ruby-Wget","Cookie" => @cookie}).read
      json = JSON.parse(request[16...-3])[0]
    end

    def set_attributes_from_json(json)
      @id               = json['itemId'] if @id.nil?
      @title            = json['title']
      @description      = json['description']
      @guid             = json['postsGuid']
      @deleted          = json['deleted']
      @views            = json['views'] if json['views']
      @tags             = json['tags'].join(",")
      @thumbnail_url    = json['thumbnailUrl']
      @thumbnail120_url = json['thumbnail120Url']
      @author           = json['login']
      @update_time      = Time.at(json['datestampUnixtime'].to_i)
      @embed_url        = json['embedUrl']
      @embed_code       = json['embedCode']
    end

    #
    # Refresh the current video object. Useful to check up on encoding progress,
    # etc.
    #
    def refresh
      update_attributes_from_id(@id)
    end

    #
    # delete! will delete the file from Blip.tv
    #
    def delete!(creds = {}, section = "file", reason = "because")
      BlipTV::ApiSpec.check_attributes('videos.delete', creds)

      reason = reason.gsub(" ", "%20") # TODO write a method to handle this and other illegalities of URL

      if creds[:username] && !creds[:userlogin]
        creds[:userlogin] = creds[:username]
      end

      url, path = "www.blip.tv", "/?userlogin=#{creds[:userlogin]}&password=#{creds[:password]}&cmd=delete&s=file&id=#{@id}&reason=#{reason}&skin=api"
      request = Net::HTTP.get(url, path)
      hash = Hash.from_xml(request)
      make_sure_video_was_deleted(hash)
    end

    private

    #
    # Makes sense out of Blip.tv's strucutre of the <tt>tag</tt> element
    #
    # returns a String
    #
    def parse_tags(element)
      if element.class == Hash && element['string']
        if element['string'].class == Array
          return element['string'].join(", ")
        elsif element['string'].class == String
          return element['string']
        end
      else
        return ""
      end
    end

    #
    # make_sure_video_was_deleted analyzes the response <tt>hash</tt>
    # to make sure it was a success
    #
    # raises a descriptive BlipTV::VideoDeleteError
    #
    def make_sure_video_was_deleted(hash)
      # TODO have a special case for authentication required?
      if hash["response"]["status"] != "OK"
        begin
          raise VideoDeleteError.new("#{hash['response']['error']['code']}: #{hash['response']['error']['message']} ")
        rescue NoMethodError # TODO irony!
          raise VideoDeleteError.new(hash.to_yaml)
        end
      end
    end
  end
end
