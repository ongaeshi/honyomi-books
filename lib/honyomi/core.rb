require 'honyomi'
require 'fileutils'
require 'rack'

module Honyomi
  class Core
    attr_reader :database

    def initialize(opts = {})
      @opts = opts
    end

    def init_database
      FileUtils.mkdir_p(db_dir)
      Groonga::Database.create(path: db_path)
      @database = Database.new
    end

    def load_database
      Groonga::Database.open(db_path)
      @database = Database.new
    end

    def add(filename, options = {})
      if File.exist?(filename)
        pages = Pdf.new(filename).pages
        pages = pages.map { |page| Util.strip_page(page) } if options[:strip]
        @database.add_book(filename, pages, options)
      else
        nil
      end
    end

    def update(book_id, options)
    end

    def edit(book_id, options)
      opts = {}
      opts[:title] = options[:title] if options[:title]
      opts[:path]  = options[:path]  if options[:path]

      if options[:strip]
        opts[:pages] = @database.book_pages(book_id).map do |page|
          page.text ? Util.strip_page(page.text) : ""
        end
      end

      @database.change_book(book_id, opts)
    end
    
    def remove(book_id)
      @database.delete_book(book_id)
    end

    def search(query)
      @database.search(query)
    end

    def list(args)
      if args.empty?
        id_length = @database.books.max { |book| book.id.to_s.length }
        id_length = id_length.id.to_s.length

        @database.books.map do |book|
          # "#{book.id} #{book.title} (#{book.page_num} pages) #{book.path}"
          "#{book.id.to_s.rjust(id_length)} #{book.title} (#{book.page_num} pages)"
        end
      else
        args.map do |book_id| 
          book = @database.books[book_id]
          <<EOF
id:    #{book.id.to_s}
title: #{book.title}
path:  #{book.path}
pages: #{book.page_num}

EOF
        end
      end
    end

    def web
      options = {
        :environment => ENV['RACK_ENV'] || "development",
        :pid         => nil,
        :Port        => 9295,
        :Host        => "0.0.0.0",
        :AccessLog   => [],
        :config      => "config.ru",
        # ----------------------------
        :server      => "thin",
      }

      # Move to the location of the server script
      FileUtils.cd(File.join(File.dirname(__FILE__), 'web'))

      # Create Rack Server
      rack_server = Rack::Server.new(options)

      # Start Rack
      rack_server.start do
        # Launchy.open(launch_url) if launch_url
      end
    end

    private

    def home_dir
      unless @home_dir
        @home_dir = @opts[:home_dir] || File.join(default_home, '.honyomi')
        FileUtils.mkdir_p(@home_dir) unless File.exist?(@home_dir)
      end
      
      @home_dir
    end

    def db_dir
      ENV['HONYOMI_DATABASE_DIR'] || File.join(home_dir, 'db')
    end

    def db_path
      File.join(db_dir, 'honyomi.db')
    end

    def default_home
      File.expand_path '~'
    end
  end
end
