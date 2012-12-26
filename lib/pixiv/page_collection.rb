module Pixiv
  module PageCollection
    def first?
      next_url.nil?
    end

    def last?
      prev_url.nil?
    end

    def next_url
      raise NotImplementError
    end

    def prev_url
      raise NotImplementError
    end

    def page_class
      raise NotImplementError
    end

    def page_hashes
      raise NotImplementError
    end

    def page_urls
      page_hashes.map {|h| h[:url] }
    end

    def size
      page_hashes.size
    end
  end

  class PageCollection::Enumerator
    include Enumerable

    def initialize(client, collection, include_deleted_page = false)
      @client = client
      @collection = collection
      @include_deleted_page = include_deleted_page
    end

    def each_page
      each_collection do |collection|
        pages_from_collection(collection).each do |page|
          next if page.nil? && !@include_deleted_page
          yield page
        end
      end
    end

    alias each each_page

    def each_slice(n = nil)
      if n
        super
      else
        if block_given?
          each_collection do |collection|
            yield pages_from_collection(collection)
          end
        else
          ::Enumerator.new {|y|
            each_slice do |slice|
              y << (@include_deleted_page ? slice.compact : slice)
            end
          }
        end
      end
    end

    def each_collection
      collection = @collection
      loop do
        yield collection
        next_url = collection.next_url or break
        collection = collection.class.lazy_new { @client.agent.get(next_url) }
      end
    end

    def count(*item)
      if item.empty? && !block_given? && @collection.respond_to?(:total_count)
         @collection.total_count
      else
        super
      end
    end

    private

    def pages_from_collection(collection)
      collection.page_hashes.map {|attrs|
        if attrs
          url = attrs.delete(:url)
          collection.page_class.lazy_new(attrs) { @client.agent.get(url) }
        end
      }
    end
  end
end
