require 'mongo'
# require 'bson_ext'

module Ankusa
  class MongoDbStorage

    def initialize(opts={})
      options = { :host => "localhost", :port => 27017, :db => "ankusa",
                  :frequency_tablename => "word_frequencies", :summary_tablename => "summary"
                }.merge(opts)

      @db = Mongo::Connection.new(options[:host], options[:port]).db(options[:db])
      @db.authenticate(options[:username], options[:password]) if options[:password]

      @ftablename = options[:frequency_tablename]
      @stablename = options[:summary_tablename]

      @klass_word_counts = {}
      @klass_doc_counts = {}
    end

    def init_tables
      @db.create_collection(@ftablename) unless @db.collection_names.include?(@ftablename)
      freq_table.create_index('word')

      @db.create_collection(@stablename) unless @db.collection_names.include?(@stablename)
      summary_table.create_index('klass')
    end

    def classnames
      @classnames ||= summary_table.distinct('klass')
    end

    def drop_tables
      @db.drop_collection(@ftablename)
      @db.drop_collection(@stablename)
    end

    def reset
      drop_tables
      init_tables
    end

    def incr_word_count(klass, word, count)
      freq_table.update({:word => word}, { '$inc' => {klass => count} }, :upsert => true)
    end

    def update_vocabulary_size(klass, word, count)
      word_doc = freq_table.find_one({:word => word})
      if word_doc[klass.to_s] == count
        multiple_incr_summary(klass, { 'vocabulary_size' => 1 })
      elsif word_doc[klass.to_s] == 0
        multiple_incr_summary(klass, { 'vocabulary_size' => -1 })
      end
    end

    def incr_total_summary_statements(klass, word_count, doc_count)
      multiple_incr_summary(klass, { 'word_count' => word_count, 'doc_count' => doc_count })
    end

    def get_word_counts(word)
      counts = Hash.new(0)

      word_doc = freq_table.find_one({:word => word})
      if word_doc
        word_doc.delete("_id")
        word_doc.delete("word")
        #convert keys to symbols
        counts.merge!(word_doc.inject({}){|h, (k, v)| h[(k.to_sym rescue k) || k] = v; h}) 
      end

      counts
    end

    def get_words_counts(words)
      words_doc = freq_table.find({'word' => {'$in' => words}})
      counts = Hash.new(0)

      words_doc.each do |doc|
        next unless doc

        counts_hash = Hash.new(0)
        word = doc["word"]

        doc.delete("_id")
        doc.delete("word")

        #convert keys to symbols
        converted_counts = doc.inject({}) do |h, (k, v)| 
          h[(k.to_sym rescue k) || k] = v
          h
        end
        counts_hash.merge!(converted_counts) 

        counts[word] = counts_hash
      end

      counts
    end

    def get_total_word_count
      @count_unique_words ||= freq_table.distinct("word").count.to_f
      # klass_doc = summary_table.find_one(:klass => klass)
      # klass_doc ? klass_doc['word_count'].to_f : 0.0
    end

    def doc_count_totals
      count = Hash.new(0)

      summary_table.find.each do |doc|
        count[ doc['klass'] ] = doc['doc_count']
      end

      count
    end

    def get_vocabulary_sizes
      count = Hash.new(0)

      summary_table.find.each do |doc|
        count[ doc['klass'] ] = doc['vocabulary_size']
      end

      count
    end

    def get_doc_count(klass)
      klass_doc = summary_table.find_one(:klass => klass) 
      klass_doc ? klass_doc['doc_count'].to_f : 0.0
    end

    def close
    end


    private
    def summary_table
      @stable ||= @db[@stablename]
    end

    def freq_table
      @ftable ||= @db[@ftablename]
    end

    def multiple_incr_summary(klass, statements)
      summary_table.update({:klass => klass}, { '$inc' => statements }, :upsert => true)
    end

  end
end
