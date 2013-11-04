module Ankusa

  module Classifier
    attr_reader :classnames

    def initialize(storage)
      @storage = storage
      @storage.init_tables
      @classnames = @storage.classnames
    end

    # text can be either an array of strings or a string
    # klass is a symbol
    def train(klass, text)
      th = TextHash.new(text)
      th.each do |word, count|
        @storage.incr_word_count klass, word, count
        @storage.update_vocabulary_size klass, word, count
        yield word, count if block_given?
      end

      doc_count = (text.kind_of? Array) ? text.length : 1
      @storage.incr_total_summary_statements(klass, th.word_count, doc_count)
      @classnames << klass unless @classnames.include? klass

      th
    end

    # text can be either an array of strings or a string
    # klass is a symbol
    def untrain(klass, text)
      th = TextHash.new(text)
      th.each do |word, count|
        @storage.incr_word_count klass, word, -count
        @storage.update_vocabulary_size klass, word, -count
        yield word, count if block_given?
      end

      doccount = (text.kind_of? Array) ? text.length : 1
      @storage.incr_total_summary_statements(klass, -th.word_count, -doc_count)

      th
    end

    protected
    def get_word_probs(class_counts_hash, classnames)
      probs = Hash.new 0
      class_counts_hash.each do |classname, count| 
        probs[classname] = count if classnames.include? classname 
      end

      classnames.each do |classname|
        # if we've never seen the class, the word prob is 0
        next unless vocab_sizes.has_key? classname
        # use a laplacian smoother
        # @storage.get_total_word_count(classname)
        probs[classname] = (probs[classname] + 1).to_f / (@storage.get_total_word_count + vocab_sizes[classname]).to_f
      end

      probs
    end

    def multi_get_word_probs(words, classnames)
      probs = Hash.new 0
      @storage.get_words_counts(words).each do |word, class_counts_hash|
        probs[word] = get_word_probs(class_counts_hash, classnames)
      end
      
      probs
    end

    def doc_count_totals
      @doc_count_totals ||= @storage.doc_count_totals
    end

    def vocab_sizes
      @vocab_sizes ||= @storage.get_vocabulary_sizes
    end
  end
end
