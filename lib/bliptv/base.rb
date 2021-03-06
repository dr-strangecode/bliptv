module BlipTV
  # Generic BlipTV exception class.
  class BlipTVError < StandardError #:nodoc:
  end

  # Raised when username and password has not been set.
  class AuthenticationRequiredError < BlipTVError #:nodoc:
    def message
      "Method that you're trying to execute requires username and password."
    end
  end

  # Raised when calling not yet implemented API methods.
  class NotImplementedError < BlipTVError #:nodoc:
    def message
      'This method is not yet implemented.'
    end
  end

  #
  # This is the class that should be instantiated for basic
  # communication with the Blip.tv API
  #
  class Base
    attr_accessor :username, :password, :cookie

    # TODO allow user to specify userlogin and password on intialize
    def initialize(attributes={})
      attributes.each do |k,v|
        respond_to?(:"#{k}=") ? send(:"#{k}=", v) : raise(NoMethodError, "Unknown method #{k}")
      end
      #set the cookie
      if @username and @password
        login = open("http://blip.tv/dashboard/?userlogin=#{@username}&password=#{@password}")
        @cookie = login.meta['set-cookie'].split('; ',2)[0]
      end

    end

    # Implements the Blip.tv REST Upload API
    #
    # <tt>new_attributes</tt> hash should contain next required keys:
    # * <tt>title:</tt> The video title;
    # * <tt>file:</tt> The video file;
    #
    # and optionally:
    # * <tt>thumbnail:</tt> A thumbnail file;
    # * <tt>nsfw:</tt> true if explicit, false otherwise. Defaults to false;
    # * <tt>description:</tt> A description of the video
    # * <tt>username:</tt> Username
    # * <tt>password:</tt> Password
    # * <tt>keywords:</tt> A comma-separated string of keywords # TODO this should be nice and also accept Arrays
    # * <tt>categories:</tt> A Hash of categories
    # * <tt>license:</tt> A license for the video
    # * <tt>interactive_post:</tt> Specify whether or not a post is interactive. More here[http://wiki.blip.tv/index.php/API_2.0:_Post_Interactivity]
    #
    # Example:
    #
    #  bliptv.upload_video(:title => 'Check out this guy getting kicked in the nuts!', :file => File.open('/movies/nuts.mov'))
    #
    # Returns BlipTV::Video instance.
    #
    def upload_video(new_attributes={})
      BlipTV::ApiSpec.check_attributes('videos.upload', new_attributes)

      new_attributes = {
        :post => "1",
        :item_type => "file",
        :skin => "xmlhttprequest",
        :file_role => "Web"
      }.merge(new_attributes) # blip.tv requires the "post" param to be set to 1

      request = BlipTV::Request.new(:post, 'videos.upload')
      request.run do |p|
        for param, value in new_attributes
          p.send("#{param}=", value)
        end
      end

      BlipTV::Video.new(request.response['post_url'].to_s)
    end


    # Looks up all videos on Blip.tv with a given <tt>username</tt>
    #
    # Options hash could contain next values:
    # * <tt>page</tt>: The "page number" of results to retrieve (e.g. 1, 2, 3); if not specified, the default value equals 1.
    # * <tt>pagelen</tt>: The number of results to retrieve per page (maximum 100). If not specified, the default value equals 20.
    #
    # Example:
    #
    #  bliptv.find_all_videos_by_user("username")
    #    or
    #  bliptv.find_all_videos_by_user("username", {:page => 1, :pagelen => 20})
    #
    # Returns array of BlipTV::Video objects.
    #
    def find_all_videos_by_user(username, options={})
      options[:page] ||= 1; options[:pagelen] ||= 20
      #url = "http://#{username}.blip.tv/posts/?skin=json&version=2&page=#{options[:page]}&pagelen=#{options[:pagelen]}"
      url = "http://#{username}.blip.tv/posts/?skin=json&version=2"
      request = open(url,{"UserAgent" => "Ruby-Wget"}).read
      json = JSON.parse(request[16...-3])
      parse_json_videos_list(json)
    end

    # Looks up all videos on Blip.tv from the setup login <tt>username</tt>
    #
    # Options hash could contain next values:
    # * <tt>page</tt>: The "page number" of results to retrieve (e.g. 1, 2, 3); if not specified, the default value equals 1.
    # * <tt>pagelen</tt>: The number of results to retrieve per page (maximum 100). If not specified, the default value equals 20.
    #
    # Example:
    #
    #  bliptv.all_videos_from_login
    #    or
    #  bliptv.all_videos_from_login({:page => 1, :pagelen => 20})
    #
    # Returns array of BlipTV::Video objects.
    #
    def all_videos_from_login(options={})
      options[:page] ||= 1; options[:pagelen] ||= 200
      #use the cookie
      #url = "http://#{@username}.blip.tv/posts?skin=json&version=2&page=#{options[:page]}&pagelen=#{options[:pagelen]}"
      url = "http://#{@username}.blip.tv/posts?skin=json&version=2"
      request = open(url,{"UserAgent" => "Ruby-Wget","Cookie" => @cookie}).read
      json = JSON.parse(request[16...-3])
      parse_json_videos_list(json)
      #hash = Hash.from_xml(request)
      #hash.nil? ? [] : parse_videos_list(hash)
    end

    # Searches through and returns videos based on the <tt>search_string</tt>.
    #
    # This method is a direct call of Blip.tv's search method. You get what you get. No guarantees are made.
    #
    # Example:
    #
    #   bliptv.search_videos("cool stuff")
    #
    # Returns an array of BlipTV::Video objects
    #
    def search_videos(search_string)
      url = "http://www.blip.tv/search/?search=#{search_string}&skin=json"
      request = open(url,{"UserAgent" => "Ruby-Wget"}).read
      json = JSON.parse(request[16...-3])
      parse_json_videos_list(json)
    end

    private

    def parse_json_videos_list(json,options={})
      list = []
      begin
        json.each do |j|
          list << Video.new(j,{:cookie => @cookie,:json => true})
        end
      rescue NoMethodError
        return list
      end
      return list
    end

    def parse_videos_list(hash,options={})
      list = []
      begin
        hash["response"]["payload"]["asset"].each do |entry|
          if @cookie
            list << Video.new(entry,{:cookie => @cookie})
          else
            list << Video.new(entry)
          end
        end
      rescue NoMethodError
        list = []
      end
      list
    end
  end
end
